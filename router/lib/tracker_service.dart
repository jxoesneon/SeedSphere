import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:router/db_service.dart';
import 'package:router/health_service.dart';
import 'package:router/boost_service.dart';

/// Service for coordinating Distributed Tracker Reputation.
///
/// 1. Ingests master list from ngosang.
/// 2. Aggregates votes from Gardeners.
/// 3. Provides "Best" list based on community scores.
class TrackerService {
  final DbService _db;
  final HealthService
  _health; // Used for minimal baseline check (DNS) if needed

  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  static const _refreshInterval = Duration(hours: 24);

  // Source: ngosang/trackerslist - All IPs
  static const _sourceUrl =
      'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt';

  TrackerService(this._db, this._health);

  /// Initializes the service.
  Future<void> init() async {
    // Ingest immediately if DB is empty or stale
    final stored = _db.getTrackers();
    print('TrackerService: Loaded ${stored.length} trackers from DB.');

    // Background verification loop
    unawaited(_verificationLoop());
  }

  Future<void> _verificationLoop() async {
    while (true) {
      await Future.delayed(Duration(minutes: 5));
      final trackers = _db.getTrackers();
      if (trackers.isEmpty) continue;

      // Randomly check a few
      for (var i = 0; i < 5; i++) {
        // Simple ping logic here
      }
    }
  }

  /// Fetches the master list from ngosang and ingests into DB.
  /// Does NOT verify them. Leaves verification to Gardeners.
  Future<void> refreshMasterList() async {
    try {
      print('TrackerService: Ingesting master list from ngosang...');
      final res = await http.get(Uri.parse(_sourceUrl));
      if (res.statusCode == 200) {
        final allTrackers = res.body
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && !e.startsWith('#'))
            .toList();

        // Batch insert/ignore
        // DbService handles dedupe via IGNORE
        // Can be slow if 1 by 1. Transaction?
        _db.transaction(() {
          for (final tr in allTrackers) {
            _db.upsertTracker(tr);
          }
          return true;
        });

        print('TrackerService: Ingested ${allTrackers.length} trackers.');
      }
    } catch (e) {
      print('TrackerService: Ingestion error: $e');
    }
  }

  /// Returns the curated best trackers (Top 50 by score).
  List<String> getBestTrackers() {
    return _db.getBestTrackers(limit: 50);
  }

  /// Used by Gardeners to sync the full list for active verification.
  List<String> getSyncList() {
    return _db.getTrackersSync();
  }

  /// Submits a batch of votes from a Gardener.
  void submitVotes(List<Map<String, dynamic>> votes) {
    _db.transaction(() {
      for (final v in votes) {
        final url = v['url'] as String?;
        final up = v['up'] as bool?;
        final latency = v['latency'] as int? ?? 0;

        if (url != null && up != null) {
          _db.submitTrackerVote(url, up, latency);
        }
      }
      return true;
    });
  }

  /// Legacy optimize endpoint compat:
  /// Injects System Best into incoming list.
  /// Also opportunistically ingests verified incoming trackers?
  /// For now, just injects "Best".
  Future<Map<String, dynamic>> optimize(List<String> incoming) async {
    // 1. Ingest incoming (discover new trackers)
    for (final tr in incoming) {
      _db.upsertTracker(tr);
    }

    // 2. Return BEST system trackers to client
    final best = getBestTrackers();

    // Boost: Emit event
    if (best.isNotEmpty) {
      BoostService().add(
        'optimize',
        'Optimized with ${best.length} trackers',
        details:
            'Found ${incoming.length} incoming, injected ${best.length} best system trackers.',
        result: {'added': best.length, 'incoming': incoming.length},
      );
    }

    // We don't filter 'bad' here because we aren't verifying them on the fly anymore.
    // The client/bridge will receive the 'best' list and can append it.

    return {
      'good': incoming, // Return as-is, we can't vouch for them instantly
      'added': best, // But here are some we know are great
    };
  }

  /// Sweeps a source URL: fetches list and streams verification results.
  Stream<Map<String, dynamic>> sweep(String sourceUrl) async* {
    if (sourceUrl.isEmpty) return;
    try {
      yield {'type': 'info', 'msg': 'Fetching $sourceUrl...'};
      final res = await http
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        yield {'type': 'error', 'msg': 'HTTP ${res.statusCode}'};
        return;
      }

      final candidates = res.body
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && !e.startsWith('#'))
          .toList();

      yield {
        'type': 'info',
        'msg': 'Found ${candidates.length} candidates. Verifying...',
      };

      int processed = 0;
      int healthy = 0;

      // Parallel-ish verification?
      // Limit concurrency to avoid file descriptor limits.
      // Chunk size 10?

      for (final url in candidates) {
        processed++;
        bool ok = false;
        // Try UDP strict first if UDP
        if (url.startsWith('udp')) {
          ok = await _health.checkUdpTracker(
            url,
            timeout: const Duration(seconds: 2),
          );
        } else {
          // Basic HTTP/DNS check
          ok = await _health.checkHealthy(url);
        }

        if (ok) healthy++;

        yield {
          'type': 'result',
          'url': url,
          'ok': ok,
          'progress': processed / candidates.length,
        };

        // Ingest healthy ones?
        if (ok) {
          _db.upsertTracker(url);
          // Boost event for bulk sweeps not needed per item, maybe only summary
        }
      }

      yield {
        'type': 'done',
        'stats': {'total': candidates.length, 'healthy': healthy},
      };
    } catch (e) {
      yield {'type': 'error', 'msg': 'Sweep failed: $e'};
    }
  }
}

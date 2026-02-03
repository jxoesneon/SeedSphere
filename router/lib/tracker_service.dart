import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:router/db_service.dart';
import 'package:router/health_service.dart';
import 'package:router/boost_service.dart';

/// Service for coordinating Distributed Tracker Reputation.
class TrackerService {
  final DbService _db;
  final HealthService _health;
  final Set<String> _privateIps = {'127.0.0.1', 'localhost', '::1'};
  final Logger _logger = Logger('TrackerService');

  // Source: ngosang/trackerslist - All IPs
  static const _sourceUrl =
      'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt';

  /// Creates a new TrackerService.
  TrackerService(this._db, this._health);

  /// Initializes the service.
  Future<void> init() async {
    // Ingest immediately if DB is empty or stale
    final stored = _db.getTrackers();
    _logger.info('TrackerService: Loaded ${stored.length} trackers from DB.');

    // Background verification loop
    unawaited(_verificationLoop());
  }

  Future<void> _verificationLoop() async {
    while (true) {
      await Future.delayed(const Duration(minutes: 5));
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
      _logger.info('TrackerService: Ingesting master list from ngosang...');
      final res = await _safeGet(_sourceUrl);
      if (res != null && res.statusCode == 200) {
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

        _logger.info(
          'TrackerService: Ingested ${allTrackers.length} trackers.',
        );
      }
    } catch (e) {
      _logger.warning('TrackerService: Ingestion error: $e');
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

    // Security check: ensure incoming trackers don't resolve to private IPs
    final safeIncoming = <String>[];
    for (final tr in incoming) {
      if (await _isSafeTracker(tr)) {
        _db.upsertTracker(tr);
        safeIncoming.add(tr);
      }
    }

    return {
      'good': safeIncoming,
      'added': best, // But here are some we know are great
    };
  }

  Future<bool> _isSafeTracker(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return false;
      if (_privateIps.contains(host)) return false;

      final ips = await InternetAddress.lookup(host);
      for (final ip in ips) {
        if (ip.isLoopback || ip.isLinkLocal) return false;
        final first = ip.rawAddress[0];
        final second = ip.rawAddress[1];
        if (ip.type == InternetAddressType.IPv4) {
          if (first == 10) return false;
          if (first == 172 && (second >= 16 && second <= 31)) return false;
          if (first == 192 && second == 168) return false;
        } else if (ip.type == InternetAddressType.IPv6) {
          if ((ip.rawAddress[0] & 0xFE) == 0xFC) return false;
          // IPv4-mapped check
          if (ip.rawAddress.length == 16 &&
              ip.rawAddress[10] == 0xff &&
              ip.rawAddress[11] == 0xff) {
            final f = ip.rawAddress[12];
            final s = ip.rawAddress[13];
            if (f == 10 ||
                (f == 172 && (s >= 16 && s <= 31)) ||
                (f == 192 && s == 168) ||
                f == 127) {
              return false;
            }
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response?> _safeGet(String url, {Duration? timeout}) async {
    if (!await _isSafeTracker(url)) return null;
    final uri = Uri.parse(url);
    final ips = await InternetAddress.lookup(uri.host);
    if (ips.isEmpty) return null;

    // Pin to first safe IP
    final safeIp = ips.first;
    var ipHost = safeIp.address;
    if (safeIp.type == InternetAddressType.IPv6 && !ipHost.startsWith('[')) {
      ipHost = '[$ipHost]';
    }

    final pinnedUri = uri.replace(host: ipHost);
    final request = http.Request('GET', pinnedUri);
    request.followRedirects = false; // Prevent SSFR via redirects
    request.headers['Host'] = uri.host;

    final streamed = await request.send().timeout(
      timeout ?? const Duration(seconds: 10),
    );
    return http.Response.fromStream(streamed);
  }

  /// Sweeps a source URL: fetches list and streams verification results.
  Stream<Map<String, dynamic>> sweep(String sourceUrl) async* {
    if (sourceUrl.isEmpty) return;
    try {
      yield {'type': 'info', 'msg': 'Fetching $sourceUrl...'};
      final res = await _safeGet(
        sourceUrl,
        timeout: const Duration(seconds: 10),
      );
      if (res == null || res.statusCode != 200) {
        yield {'type': 'error', 'msg': 'Fetch failed or unsafe'};
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

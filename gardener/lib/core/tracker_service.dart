import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for managing dynamic tracker lists.
///
/// Ports logic from `legacy/server/lib/addon.cjs` (fetching/caching)
/// and `legacy/server/lib/health.cjs` (validation).
///
/// - Fetches `trackers_best_ip.txt` from GitHub (or configured variant).
/// - Caches results for 12 hours (matching legacy `VARIANT_TTLS`).
/// - Falls back to hardcoded `NetworkConstants.verifiedTrackers` on failure.
class TrackerService {
  static final TrackerService _instance = TrackerService._internal();
  factory TrackerService() => _instance;
  TrackerService._internal();

  /// Variant URLs from legacy addon.cjs
  static const Map<String, String> _variantUrls = {
    'all':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt',
    'best':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt',
    'all_udp':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_udp.txt',
    'all_http':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_http.txt',
    'all_ws':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ws.txt',
    'all_ip':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt',
    'best_ip':
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt',
  };

  /// Cache TTL: 12 hours
  static const Duration _cacheTtl = Duration(hours: 12);

  List<String>? _cachedTrackers;
  String? _cachedVariant; // Last used variant/url key
  DateTime? _lastFetchTime;

  /// Returns the optimized list of trackers.
  ///
  /// Returns cached list if valid and configuration hasn't changed.
  /// Otherwise triggers a fetch.
  /// Always returns a non-empty list (falls back to constants).
  Future<List<String>> getTrackers() async {
    final config = ConfigManager();
    final customUrl = config.customTrackersUrl;
    final variant = config.trackerVariant;

    // Determine effective URL
    String targetUrl = _variantUrls['all']!;
    String cacheKey = 'all';

    if (customUrl.isNotEmpty) {
      targetUrl = customUrl;
      cacheKey = 'custom:$customUrl';
    } else {
      targetUrl = _variantUrls[variant] ?? _variantUrls['all']!;
      cacheKey = variant;
    }

    // Check cache validity (time + config match)
    if (_cachedTrackers != null &&
        _lastFetchTime != null &&
        _cachedVariant == cacheKey) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheTtl) {
        return _cachedTrackers!;
      }
    }

    return await _fetchTrackers(targetUrl, cacheKey);
  }

  Future<List<String>> _fetchTrackers(String url, String cacheKey) async {
    try {
      debugPrint('TrackerService: Fetching trackers from $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final valid = <String>{}; // Dedupe

        for (var line in lines) {
          final t = line.trim();
          if (t.isNotEmpty && _isTrackerUrl(t)) {
            valid.add(t);
          }
        }

        // 3. Probing Phase (Gap Closure: Tracker Health Validation)
        final ConfigManager config = ConfigManager();
        if (config.probeTrackers && valid.isNotEmpty) {
          debugPrint('TrackerService: Probing ${valid.length} trackers...');
          final trackerList = valid.toList();
          final healthy = <String>[];

          // Probe in batches of 10 to avoid socket exhaustion
          for (int i = 0; i < trackerList.length; i += 10) {
            final batch = trackerList.skip(i).take(10);
            final results = await Future.wait(
              batch.map((t) => _probeTracker(t)),
            );
            for (int j = 0; j < results.length; j++) {
              if (results[j]) healthy.add(batch.elementAt(j));
            }
          }

          if (healthy.isNotEmpty) {
            _cachedTrackers = healthy;
            debugPrint(
              'TrackerService: Found ${healthy.length} healthy trackers.',
            );
          } else {
            debugPrint(
              'TrackerService: No healthy trackers found in probe, using raw list.',
            );
            _cachedTrackers = valid.toList();
          }
        } else {
          _cachedTrackers = valid.toList();
        }

        _cachedVariant = cacheKey;
        _lastFetchTime = DateTime.now();
        return _cachedTrackers!;
      }
    } catch (e) {
      debugPrint('TrackerService: Error fetching trackers: $e');
    }

    // Fallback to constants on any error or non-200
    _cachedTrackers = List.from(NetworkConstants.verifiedTrackers);
    _cachedVariant = cacheKey;
    _lastFetchTime = DateTime.now();
    return _cachedTrackers!;
  }

  /// Probes a tracker for basic reachability (DNS + Socket bind).
  Future<bool> _probeTracker(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.port;

      if (host.isEmpty) return false;

      // 1. DNS Resolution (Primary check)
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty) return false;

      // 2. Protocol specific probe (Secondary check)
      if (uri.scheme == 'udp') {
        // Just verify we can resolve it for now (UDP is fire and forget anyway without full scrape packet)
        return true;
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        // Rapid response check
        final conn = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 2),
        );
        await conn.close();
        return true;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates if a string looks like a valid tracker URL.
  /// Port of `legacy/server/lib/health.cjs` regex logic.
  bool _isTrackerUrl(String s) {
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    return lower.startsWith('udp://') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('ws://') ||
        lower.startsWith('wss://');
  }

  /// Exports the current list of trackers as a string.
  Future<String> exportTrackers() async {
    final list = await getTrackers();
    return list.join('\n');
  }

  /// Clears cache and re-validates trackers.
  Future<List<String>> sweepTrackers() async {
    clearCache();
    return await getTrackers();
  }

  /// For testing: clear cache
  @visibleForTesting
  void clearCache() {
    _cachedTrackers = null;
    _cachedVariant = null;
    _lastFetchTime = null;
  }
}

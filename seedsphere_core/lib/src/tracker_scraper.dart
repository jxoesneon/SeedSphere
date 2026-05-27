import 'dart:async';

import 'core/tracker_service.dart';
import 'core/udp_tracker_client.dart';
import 'core/app_config.dart';

/// Scraper that uses UDP trackers to find seeder/leecher counts for magnets.
class TrackerScraper {
  final AppConfig _config;
  final TrackerService _trackerService;

  /// Creates a new TrackerScraper.
  TrackerScraper({
    required AppConfig config,
    TrackerService? trackerService,
  }) : _config = config,
       _trackerService = trackerService ?? TrackerService();

  /// Refreshes seeder/leecher counts for a list of streams using UDP trackers.
  Future<void> refreshSeederCounts(List<Map<String, dynamic>> streams) async {
    if (!_config.enableTrackerScraping || streams.isEmpty) return;

    final trackers = await _trackerService.getTrackers(_config);
    if (trackers.isEmpty) return;

    final List<Future<void>> futures = [];

    // Only process a limited number of streams to avoid spamming trackers
    final targets = streams.length > 20 ? streams.take(20) : streams;

    for (var stream in targets) {
      final infoHash = stream['infoHash'] as String?;
      if (infoHash == null || infoHash.isEmpty) continue;

      futures.add(_scrapeInfoHash(infoHash, trackers).then((counts) {
        if (counts != null) {
          stream['seeders'] = counts.seeders;
          stream['peers'] = counts.leechers;
        }
      }));
    }

    await Future.wait(futures).timeout(const Duration(seconds: 15), onTimeout: () => []);
  }

  Future<({int seeders, int leechers})?> _scrapeInfoHash(
    String infoHash,
    List<String> trackers,
  ) async {
    final client = UdpTrackerClient();
    
    // Attempt top 3 trackers
    final topTrackers = trackers.take(3);
    
    for (var trackerUrl in topTrackers) {
      try {
        final result = await client.scrape(trackerUrl, [infoHash]);
        if (result.isNotEmpty && result.containsKey(infoHash)) {
          return result[infoHash];
        }
      } catch (_) {
        // Continue to next tracker
      }
    }
    
    return null;
  }
}

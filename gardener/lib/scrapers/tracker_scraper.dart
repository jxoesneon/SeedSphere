import 'dart:async';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/tracker_service.dart';
import 'package:gardener/core/udp_tracker_client.dart';

/// Refreshes seeder and leecher counts for discovered streams using direct UDP scraping.
class TrackerScraper {
  final ConfigManager _config;
  final TrackerService _trackerService;

  TrackerScraper({ConfigManager? config, TrackerService? trackerService})
    : _config = config ?? ConfigManager(),
      _trackerService = trackerService ?? TrackerService();

  /// Refreshes the seeder counts in the provided [streams] list.
  ///
  /// Group results by infoHash and queries multiple trackers in parallel.
  /// Updates the 'seeders' field in each stream map if a more accurate count is found.
  Future<void> refreshSeederCounts(List<Map<String, dynamic>> streams) async {
    if (!_config.enableTrackerScraping || streams.isEmpty) return;

    final infoHashes = streams
        .map((s) => s['infoHash'] as String?)
        .where((h) => h != null && h.length == 40)
        .cast<String>()
        .toSet()
        .toList();

    if (infoHashes.isEmpty) return;

    DebugLogger.info(
      'TrackerScraper: Refreshing counts for ${infoHashes.length} hashes...',
    );

    // Get active trackers (limit to top 10 for performance)
    final allTrackers = await _trackerService.getTrackers();
    final targets = allTrackers
        .where((t) => t.startsWith('udp://'))
        .take(10)
        .toList();

    if (targets.isEmpty) {
      DebugLogger.warn(
        'TrackerScraper: No UDP trackers available for scraping.',
      );
      return;
    }

    final timeout = Duration(milliseconds: _config.trackerScrapeTimeoutMs);
    final resultsByHash = <String, List<int>>{};

    // Query trackers in parallel
    final scraperFutures = targets.map((trackerUrl) async {
      try {
        final uri = Uri.parse(trackerUrl);
        final client = UdpTrackerClient(
          host: uri.host,
          port: uri.port,
          timeout: timeout,
        );

        final scrapeData = await client.scrape(infoHashes);
        for (final entry in scrapeData.entries) {
          resultsByHash
              .putIfAbsent(entry.key, () => [])
              .add(entry.value['seeders'] ?? 0);
        }
      } catch (e) {
        // Individual tracker failure is expected
      }
    });

    await Future.wait(scraperFutures);

    // Update original stream maps with max seeder count found (Consensus)
    int updatedCount = 0;
    for (var stream in streams) {
      final hash = stream['infoHash'] as String?;
      if (hash != null && resultsByHash.containsKey(hash)) {
        final counts = resultsByHash[hash]!;
        if (counts.isNotEmpty) {
          final maxSeeders = counts.reduce((a, b) => a > b ? a : b);
          // Only update if we found a higher count or if the original was 0
          if (maxSeeders > (stream['seeders'] as int? ?? 0)) {
            stream['seeders'] = maxSeeders;
            updatedCount++;
          }
        }
      }
    }

    DebugLogger.info('TrackerScraper: Refreshed $updatedCount streams.');
  }
}

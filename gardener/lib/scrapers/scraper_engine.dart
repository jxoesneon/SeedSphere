import 'dart:async';
import 'package:gardener/core/metadata_normalizer.dart';

/// Base class for all torrent and stream metadata scrapers.
///
/// Each scraper implementation must extend this class and provide
/// a [scrape] method that fetches stream data for a given IMDB ID.
abstract class BaseScraper {
  /// The user-friendly name of the scraper (e.g., "YTS", "Torrentio").
  final String name;

  /// The base URL of the scraper's API service.
  final String baseUrl;

  /// Creates a [BaseScraper] instance.
  BaseScraper({required this.name, required this.baseUrl});

  /// Fetches stream metadata for the specified [imdbId].
  ///
  /// Should return a list of raw metadata maps, which will later be
  /// normalized by the [MetadataNormalizer].
  Future<List<Map<String, dynamic>>> scrape(String imdbId);
}

/// Aggregation engine for running multiple scrapers in parallel.
///
/// Simplifies the process of fetching stream metadata from various sources
/// by executing multiple [BaseScraper]s concurrently and merging their results.
///
/// Example:
/// ```dart
/// final engine = ScraperEngine(scrapers: [
///   YTSScraper(),
///   TorrentioScraper(),
/// ]);
///
/// final allStreams = await engine.scrapeAll('tt1234567');
/// ```
class ScraperEngine {
  /// The list of scrapers managed by this engine.
  final List<BaseScraper> scrapers;

  /// Creates a [ScraperEngine] with the provided [scrapers].
  ScraperEngine({required this.scrapers});

  /// Executes all configured scrapers for the given [imdbId] in parallel.
  ///
  /// Aggregates results from all scrapers into a single flat list.
  /// If an individual scraper fails, its error is caught and it contributes
  /// an empty list to the final result, allowing other scrapers to still succeed.
  ///
  /// Returns a combined list of raw metadata maps from all responsive scrapers.
  Future<List<Map<String, dynamic>>> scrapeAll(String imdbId) async {
    final List<Future<List<Map<String, dynamic>>>> futures = scrapers
        .map((s) => s.scrape(imdbId).catchError((e) {
              // Log error and return empty list for this scraper to prevent
              // a single failing scraper from breaking the entire request.
              return <Map<String, dynamic>>[];
            }))
        .toList();

    final List<List<Map<String, dynamic>>> results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }
}

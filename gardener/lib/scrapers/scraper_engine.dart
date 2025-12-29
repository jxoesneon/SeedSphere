import 'dart:async';
import 'package:gardener/core/metadata_normalizer.dart';
import 'package:gardener/scrapers/eztv_scraper.dart';
import 'package:gardener/scrapers/nyaa_scraper.dart';
import 'package:gardener/scrapers/x1337_scraper.dart';
import 'package:gardener/scrapers/piratebay_scraper.dart';
import 'package:gardener/scrapers/torrentgalaxy_scraper.dart';
import 'package:gardener/scrapers/torlock_scraper.dart';
import 'package:gardener/scrapers/magnetdl_scraper.dart';
import 'package:gardener/scrapers/anidex_scraper.dart';
import 'package:gardener/scrapers/tokyotosho_scraper.dart';
import 'package:gardener/scrapers/zooqle_scraper.dart';
import 'package:gardener/scrapers/rutor_scraper.dart';
import 'package:gardener/scrapers/torrentio_scraper.dart';
import 'package:gardener/scrapers/yts_scraper.dart';

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

  /// Creates a [ScraperEngine] configured with all supported providers.
  factory ScraperEngine.defaults() {
    return ScraperEngine(scrapers: [
      TorrentioScraper(),
      YTSScraper(),
      EztvScraper(),
      NyaaScraper(),
      X1337Scraper(),
      PirateBayScraper(),
      TorrentGalaxyScraper(),
      TorlockScraper(),
      MagnetDLScraper(),
      AnidexScraper(),
      TokyoToshoScraper(),
      ZooqleScraper(),
      RutorScraper(),
    ]);
  }

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

import 'dart:async';
import 'package:router/core/metadata_normalizer.dart';
import 'package:router/scrapers/eztv_scraper.dart';
import 'package:router/scrapers/nyaa_scraper.dart';
import 'package:router/scrapers/x1337_scraper.dart';
import 'package:router/scrapers/piratebay_scraper.dart';
import 'package:router/scrapers/torrentgalaxy_scraper.dart';
import 'package:router/scrapers/torlock_scraper.dart';
import 'package:router/scrapers/magnetdl_scraper.dart';
import 'package:router/scrapers/anidex_scraper.dart';
import 'package:router/scrapers/tokyotosho_scraper.dart';
import 'package:router/scrapers/zooqle_scraper.dart';
import 'package:router/scrapers/rutor_scraper.dart';
import 'package:router/scrapers/torrentio_scraper.dart';
import 'package:router/scrapers/yts_scraper.dart';

/// Base class for all torrent and stream metadata scrapers.
///
/// Each scraper implementation must extend this class and provide
/// a [scrape] method that fetches stream data for a given IMDB ID.
abstract class BaseScraper {
  /// The user-friendly name of the scraper (e.g., "YTS", "Torrentio").
  final String name;

  /// The base URL of the scraper's API service.
  final String baseUrl;

  /// The rate limiter for this scraper instance.
  late final RateLimiter _rateLimiter;

  /// Creates a [BaseScraper] instance.
  ///
  /// [requestsPerMinute] defaults to 30 (1 request every 2 seconds) to be safe.
  BaseScraper({
    required this.name,
    required this.baseUrl,
    int requestsPerMinute = 30,
  }) {
    _rateLimiter = RateLimiter(requestsPerMinute);
  }

  /// Fetches stream metadata for the specified [imdbId].
  ///
  /// Should return a list of raw metadata maps, which will later be
  /// normalized by the [MetadataNormalizer].
  Future<List<Map<String, dynamic>>> scrape(String imdbId);

  /// Waits if necessary to comply with the rate limit.
  Future<void> waitForRateLimit() => _rateLimiter.wait();
}

/// A simple token bucket rate limiter.
class RateLimiter {
  final int requestsPerMinute;
  final Duration _interval;
  DateTime _nextRequestTime = DateTime.now();

  RateLimiter(this.requestsPerMinute)
    : _interval = Duration(milliseconds: (60000 / requestsPerMinute).round());

  Future<void> wait() async {
    final now = DateTime.now();
    if (now.isBefore(_nextRequestTime)) {
      final waitTime = _nextRequestTime.difference(now);
      _nextRequestTime = _nextRequestTime.add(_interval);
      await Future.delayed(waitTime);
    } else {
      _nextRequestTime = now.add(_interval);
    }
  }
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
    return ScraperEngine(
      scrapers: [
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
      ],
    );
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
        .map(
          (s) => s.scrape(imdbId).catchError((e) {
            // Log error and return empty list for this scraper to prevent
            // a single failing scraper from breaking the entire request.
            return <Map<String, dynamic>>[];
          }),
        )
        .toList();

    final List<List<Map<String, dynamic>>> results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }
}

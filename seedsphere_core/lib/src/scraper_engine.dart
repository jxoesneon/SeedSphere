import 'dart:async';
import 'package:router/core/metadata_normalizer.dart';
import 'package:router/core/user_agent_rotator.dart'; // Import Rotator
import 'package:router/core/rate_limiter.dart'; // Import RateLimiter
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

  /// The current session User-Agent.
  late String _userAgent;

  /// Creates a [BaseScraper] instance.
  ///
  /// [requestsPerMinute] defaults to 30.
  BaseScraper({
    required this.name,
    required this.baseUrl,
    int requestsPerMinute = 30,
  }) {
    _rateLimiter = RateLimiter(requestsPerMinute, jitter: true);
    rotateUserAgent();
  }

  /// Rotates the User-Agent for this scraper session.
  void rotateUserAgent() {
    _userAgent = UserAgentRotator.random;
  }

  /// Gets the current User-Agent.
  String get userAgent => _userAgent;

  /// Fetches stream metadata for the specified [imdbId].
  ///
  /// Should return a list of raw metadata maps, which will later be
  /// normalized by the [MetadataNormalizer].
  Future<List<Map<String, dynamic>>> scrape(
    String imdbId, {
    Function(String)? onLog,
  });

  /// Waits if necessary to comply with the rate limit.
  Future<void> waitForRateLimit() => _rateLimiter.wait();
}

// ... (RateLimiter remains unchanged) ...

/// Aggregation engine for running multiple scrapers in parallel.
// ... (docs) ...
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
  Future<List<Map<String, dynamic>>> scrapeAll(
    String imdbId, {
    Function(String)? onLog,
  }) async {
    final List<Future<List<Map<String, dynamic>>>> futures = scrapers
        .map(
          (s) => s
              .scrape(
                imdbId,
                onLog: (msg) {
                  // Prefix log with scraper name for clarity
                  if (onLog != null) onLog('[${s.name}] $msg');
                },
              )
              .catchError((e) {
                // Log error and return empty list for this scraper to prevent
                // a single failing scraper from breaking the entire request.
                if (onLog != null) onLog('[${s.name}] Error: $e');
                return <Map<String, dynamic>>[];
              }),
        )
        .toList();

    final List<List<Map<String, dynamic>>> results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }
}

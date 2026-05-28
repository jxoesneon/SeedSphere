import 'dart:async';

import 'core/user_agent_rotator.dart';
import 'core/rate_limiter.dart';
import 'eztv_scraper.dart';
import 'nyaa_scraper.dart';
import 'x1337_scraper.dart';
import 'piratebay_scraper.dart';
import 'torrentgalaxy_scraper.dart';
import 'torlock_scraper.dart';
import 'magnetdl_scraper.dart';
import 'anidex_scraper.dart';
import 'tokyotosho_scraper.dart';
import 'zooqle_scraper.dart';
import 'rutor_scraper.dart';
import 'torrentio_scraper.dart';
import 'yts_scraper.dart';

/// Base class for all torrent and stream metadata scrapers.
abstract class BaseScraper {
  /// The user-friendly name of the scraper.
  final String name;

  /// The base URL of the scraper's API service.
  final String baseUrl;

  /// The rate limiter for this scraper instance.
  late final RateLimiter _rateLimiter;

  /// The current session User-Agent.
  late String _userAgent;

  /// Creates a [BaseScraper] instance.
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
  Future<List<Map<String, dynamic>>> scrape(
    String imdbId, {
    Function(String)? onLog,
  });

  /// Waits if necessary to comply with the rate limit.
  Future<void> waitForRateLimit() => _rateLimiter.wait();
}

/// Aggregation engine for running multiple scrapers in parallel.
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
                  if (onLog != null) onLog('[${s.name}] $msg');
                },
              )
              .then((results) => results.map((r) {
                    // Inject provider name if not present
                    if (r['provider'] == null) {
                      r['provider'] = s.name;
                    }
                    return r;
                  }).toList())
              .catchError((e) {
                if (onLog != null) onLog('[${s.name}] Error: $e');
                return <Map<String, dynamic>>[];
              }),
        )
        .toList();

    final List<List<Map<String, dynamic>>> results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }
}

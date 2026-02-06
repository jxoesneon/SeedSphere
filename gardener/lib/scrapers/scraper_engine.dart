import 'dart:async';
import 'package:gardener/p2p/p2p_manager.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/debug_logger.dart';
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
import 'package:gardener/scrapers/torznab_scraper.dart';
import 'package:gardener/scrapers/yts_scraper.dart';
import 'package:gardener/scrapers/tracker_scraper.dart';

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
  Future<List<Map<String, dynamic>>> scrape(String imdbId);

  /// Checks if this scraper is enabled in the configuration.
  bool isEnabled(ConfigManager config) => true;
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

/// Aggregation engine for running multiple scrapers in parallel.
class ScraperEngine {
  /// The list of scrapers managed by this engine.
  final List<BaseScraper> scrapers;
  final ConfigManager _config;
  final P2PManager _p2p;

  /// Creates a [ScraperEngine] with the provided [scrapers].
  ScraperEngine({
    required this.scrapers,
    ConfigManager? config,
    P2PManager? p2p,
  }) : _config = config ?? ConfigManager(),
       _p2p = p2p ?? P2PManager.instance;

  /// Creates a [ScraperEngine] configured with all supported providers.
  factory ScraperEngine.defaults({P2PManager? p2p}) {
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
        TorznabScraper(),
      ],
      config: ConfigManager(),
      p2p: p2p,
    );
  }

  /// Probes a scraper to see if it is reachable.
  Future<bool> _probe(BaseScraper scraper) async {
    if (!_config.probeProviders) return true;

    final mode = _config.validationMode;
    final timeout = Duration(milliseconds: _config.probeTimeoutMs);

    try {
      final uri = Uri.parse(scraper.baseUrl);
      final host = uri.host;

      if (mode == 'aggressive') {
        // HTTP HEAD request to verify endpoint is up
        final resp = await http.head(uri).timeout(timeout);
        return resp.statusCode <
            500; // Accept 2xx, 3xx, 4xx (4xx means server IS reachable)
      } else {
        // Basic: DNS resolution check
        final result = await InternetAddress.lookup(host).timeout(timeout);
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (e) {
      DebugLogger.warn('Probe failed for ${scraper.name}: $e');
      return false;
    }
  }

  /// Executes all configured scrapers for the given [imdbId] in parallel.
  ///
  /// Aggregates results from all scrapers into a single flat list.
  /// If an individual scraper fails, its error is caught and it contributes
  /// an empty list to the final result, allowing other scrapers to still succeed.
  ///
  /// Returns a combined list of raw metadata maps from all responsive scrapers.
  Future<List<Map<String, dynamic>>> scrapeAll(String imdbId) async {
    var targets = scrapers.where((s) => s.isEnabled(_config)).toList();

    // 1. Probing Phase (if enabled)
    if (_config.probeProviders) {
      final probeResults = await Future.wait(
        scrapers.map((s) async {
          final isAlive = await _probe(s);
          return MapEntry(s, isAlive);
        }),
      );
      targets = probeResults.where((e) => e.value).map((e) => e.key).toList();

      if (targets.length < scrapers.length) {
        DebugLogger.info(
          'Pruned ${scrapers.length - targets.length} unreachable scrapers.',
        );
      }
    }

    // 2. Scraping Phase
    final fetchTimeout = Duration(milliseconds: _config.providerFetchTimeoutMs);
    final List<Future<List<Map<String, dynamic>>>> futures = targets.map((s) {
      _p2p.addLocalEvent({
        'type': 'scraper_event',
        'event': 'start',
        'scraper': s.name,
        'imdbId': imdbId,
      });

      return s
          .scrape(imdbId)
          .timeout(fetchTimeout)
          .then((res) {
            _p2p.addLocalEvent({
              'type': 'scraper_event',
              'event': 'done',
              'scraper': s.name,
              'count': res.length,
              'imdbId': imdbId,
            });
            return res;
          })
          .catchError((e) {
            DebugLogger.warn('Timeout/Error fetching from ${s.name}');
            _p2p.addLocalEvent({
              'type': 'scraper_event',
              'event': 'error',
              'scraper': s.name,
              'imdbId': imdbId,
            });
            return <Map<String, dynamic>>[];
          });
    }).toList();

    final List<List<Map<String, dynamic>>> results = await Future.wait(futures);
    final limit = _config.maxResultsPerProvider;

    final List<Map<String, dynamic>> flattened = results.expand((list) {
      if (list.length > limit) {
        return list.take(limit);
      }
      return list;
    }).toList();

    // 3. Post-Processing: Direct UDP Scraping (Gap Closure)
    if (_config.enableTrackerScraping && flattened.isNotEmpty) {
      final trackerScraper = TrackerScraper(config: _config);
      await trackerScraper.refreshSeederCounts(flattened);
    }

    return flattened;
  }
}

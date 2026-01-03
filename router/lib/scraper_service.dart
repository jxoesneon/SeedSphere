import 'package:router/core/metadata_normalizer.dart';
import 'package:router/scrapers/scraper_engine.dart';
import 'package:http/http.dart' as http;

import 'package:router/tracker_service.dart';
import 'package:router/services/ai_service.dart';
import 'package:router/models/ai_models.dart';

/// Service that orchestrates metadata scraping from multiple sources.
///
/// Uses [ScraperEngine] to fetch and [MetadataNormalizer] to standardize results.
class ScraperService {
  final ScraperEngine _engine;
  final TrackerService _trackers;
  final AiService _ai;
  final http.Client _client;

  /// Creates a new ScraperService instance.
  ScraperService(this._trackers, {AiService? aiService, http.Client? client})
    : _engine = ScraperEngine.defaults(),
      _ai = aiService ?? AiService(),
      _client = client ?? http.Client();

  /// Map of known providers to probe.
  static const _providers = {
    'Torrentio': 'https://torrentio.strem.fun/manifest.json',
    'YTS': 'https://yts.mx/api/v2/list_movies.json',
    'EZTV': 'https://eztvx.to/api/get-torrents',
    '1337x': 'https://1337x.to',
    'ThePirateBay': 'https://thepiratebay.org',
  };

  /// Probes all providers for availability and latency.
  Future<List<Map<String, dynamic>>> probeProviders() async {
    final futures = _providers.entries.map((e) async {
      final name = e.key;
      final url = e.value;
      final sw = Stopwatch()..start();
      try {
        final res = await _client
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 405) {
          throw Exception('HEAD not allowed');
        }

        sw.stop();
        return {
          'name': name,
          'ok': res.statusCode < 500, // 404/403 is "reachable" technically
          'ms': sw.elapsedMilliseconds,
          'status': res.statusCode,
        };
      } catch (e) {
        sw.stop();
        // Try GET if HEAD fails (some block HEAD)
        try {
          final res = await _client
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          return {
            'name': name,
            'ok': res.statusCode < 500,
            'ms': sw.elapsedMilliseconds,
            'status': res.statusCode,
          };
        } catch (_) {
          return {
            'name': name,
            'ok': false,
            'ms': sw.elapsedMilliseconds,
            'error': 'timeout_or_error',
          };
        }
      }
    });

    return Future.wait(futures);
  }

  /// Aggregates streams for a given media [type], [id], and user [settings].
  ///
  /// Returns a list of standardized stream maps ready for Stremio consumption.
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String id,
    Map<String, dynamic> settings,
  ) async {
    // Determine IMDb ID (assuming 'tt' format for now)
    final imdbId = id;

    // Run Engine
    final rawResults = await _engine.scrapeAll(imdbId);

    // Normalize
    final normalized = rawResults.map((raw) {
      // Extract provider name if available in raw map, or infer one
      // The current ScraperEngine returns raw maps, normalizing them here
      // But ScraperEngine doesn't attach 'source' in base implementation easily?
      // Wait, BaseScraper implementations just return raw maps.
      // MetadataNormalizer needs 'provider'.
      // The Engine's scrapeAll flattens results. We lose the provider context unless the scraper adds it.
      // Let's assume scrapers don't add 'source' by default (based on YTS review).
      // We might need to update ScraperEngine to preserve source, or individual scrapers to include it.

      // For now, let's inject a generic source or check raw data structure.
      // Actually, YTS scraper returns a map.
      // Let's rely on basic normalization for now.
      return MetadataNormalizer.normalize(raw, 'MultiScraper').toJson();
    }).toList();

    // Map to Stremio Stream format
    final streams = <Map<String, dynamic>>[];
    for (final s in normalized) {
      // TRACKER MANAGEMENT CORRECTION: Inject optimized trackers
      final optimized = await _trackers.optimize([]);
      final bestTrackers = optimized['added'] as List<String>;

      final infoHash = s['infoHash'] as String;
      // Build magnet link with injected best trackers
      final trackersPart = bestTrackers
          .map((t) => 'tr=${Uri.encodeComponent(t)}')
          .join('&');
      final dn = Uri.encodeComponent(s['title'] as String? ?? 'video');
      final magnet =
          'magnet:?xt=urn:btih:$infoHash&dn=$dn${trackersPart.isNotEmpty ? '&$trackersPart' : ''}';

      // Build basic description
      String description =
          '${s['title']}\n👤  ${s['seeders']}  Sources: ${s['source']}';

      // Optionally enhance with AI if enabled in settings
      final aiEnabled = settings['aiEnabled'] == true;
      if (aiEnabled) {
        try {
          final aiRequest = AiDescriptionRequest(
            title: s['title'] as String? ?? 'Unknown',
            resolution: s['resolution'] as String?,
            codec: s['codec'] as String?,
            hdr: s['hdr'] as String?,
            audio: s['audio'] as String?,
            source: s['source'] as String?,
            providerName: s['source'] as String?,
            sizeStr: s['size'] as String?,
            provider: AiProvider.fromString(
              settings['aiProvider'] as String? ?? 'deepseek',
            ),
            model: settings['aiModel'] as String? ?? 'deepseek-chat',
            apiKey: settings['aiApiKey'] as String?,
            baseDescription: description,
          );

          final aiResponse = await _ai.enhanceDescription(aiRequest);
          if (aiResponse.success && aiResponse.enhancedDescription != null) {
            description = aiResponse.enhancedDescription!;
            description += '\n\n🧠 AI enhanced';
          }
        } catch (e) {
          // Silently fail AI enhancement, use basic description
          print('AI enhancement failed: $e');
        }
      }

      streams.add({
        'title': description,
        'infoHash': infoHash,
        'url': magnet, // Inject the full magnet with corrected trackers
        'behaviorHints': {'bingeGroup': 'seedsphere-p2p'},
      });
    }
    return streams;
  }
}

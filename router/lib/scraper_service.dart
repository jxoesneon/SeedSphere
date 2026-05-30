import 'package:logging/logging.dart';
import 'package:seedsphere_core/seedsphere_core.dart' hide TrackerService;
import 'package:http/http.dart' as http;

import 'package:router/tracker_service.dart';
import 'package:router/services/ai_service.dart';
import 'package:router/models/ai_models.dart';
import 'package:router/event_service.dart'; // Import EventService

/// Service that orchestrates metadata scraping from multiple sources.
///
/// Uses [ScraperEngine] to fetch and [MetadataNormalizer] to standardize results.
class ScraperService {
  final ScraperEngine _engine;
  final TrackerService _trackers;
  final Logger _logger = Logger('ScraperService');
  final AiService _ai;
  final EventService? _eventService; // Optional for debugging
  /// The internal HTTP client used for metadata enrichment and health checks.
  final http.Client httpClient;

  /// Creates a new ScraperService instance.
  ScraperService(
    this._trackers, {
    required AppConfig config,
    AiService? aiService,
    http.Client? client,
    EventService? eventService,
  }) : _engine = ScraperEngine.defaults(config),
       _ai = aiService ?? AiService(),
       _eventService = eventService,
       httpClient = client ?? http.Client();

  /// Probes all providers for health status.
  Future<List<Map<String, dynamic>>> probeProviders() async {
    final results = <Map<String, dynamic>>[];

    for (final s in _engine.scrapers) {
      bool ok = false;
      int status = 0;
      try {
        final res = await httpClient
            .get(Uri.parse(s.baseUrl))
            .timeout(const Duration(seconds: 5));
        status = res.statusCode;
        ok = status < 500;
      } catch (e) {
        _logger.warning('Probe failed for ${s.name}: $e');
      }
      results.add({
        'name': s.name,
        'baseUrl': s.baseUrl,
        'ok': ok,
        'status': status,
        'userAgent': s.userAgent,
      });
    }
    return results;
  }

  /// Fetches a dynamic catalog based on a [query].
  ///
  /// Default implementation returns empty list.
  Future<List<Map<String, dynamic>>> getDynamicCatalog(
    String type,
    String query,
    String userId,
  ) async {
    return [];
  }

  /// Aggregates streams for a given media [type], [id], and user [settings].
  ///
  /// Returns a list of standardized stream maps ready for Stremio consumption.
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String id,
    Map<String, dynamic> settings, {
    String? userId, // Optional: Target user for debug logs
    String? title,
    int? year,
  }) async {
    // Determine IMDb ID (assuming 'tt' format for now)
    final imdbId = id;

    // Define log callback if eventService and userId are available
    Function(String)? logCallback;
    if (_eventService != null && userId != null) {
      logCallback = (msg) {
        _eventService.publish(userId, 'log', {'message': msg, 'type': 'log'});
      };
    }

    // Run Engine
    final rawResults = await _engine.scrapeAll(
      imdbId,
      title: title,
      year: year,
      onLog: logCallback,
    );

    // Normalize
    final normalized = rawResults.map((raw) {
      // Inject title and year from request context if missing in raw data
      // This helps the normalizer and verifier perform better.
      if (raw['title'] == null && title != null) raw['title'] = title;
      if (raw['year'] == null && year != null) raw['year'] = year;
      
      return MetadataNormalizer.normalize(raw, raw['provider'] ?? 'MultiScraper').toJson();
    }).toList();
    // Filter out invalid streams
    final validStreams = normalized
        .where((s) => (s['infoHash'] as String).isNotEmpty)
        .toList();

    // Map to Stremio Stream format
    final streams = <Map<String, dynamic>>[];
    for (final s in validStreams) {
      // TRACKER MANAGEMENT CORRECTION: Inject optimized trackers
      final optimized = await _trackers.optimize([]);
      final bestTrackers = optimized['added'] as List<String>;

      final infoHash = (s['infoHash'] as String).toLowerCase();

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
          _logger.fine('AI enhancement failed: $e');
        }
      }

      streams.add({
        'name': 'SeedSphere\n${s['resolution'] ?? 'SD'}',
        'title': description,
        'infoHash': infoHash,
        'sources': bestTrackers.map((t) => 'tracker:$t').toList(),
        'seeders': s['seeders'] ?? 0,
        'behaviorHints': {'bingeGroup': 'seedsphere-p2p'},
      });
    }
    return streams;
  }
}

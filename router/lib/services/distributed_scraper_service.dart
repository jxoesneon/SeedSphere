import 'dart:async';
import 'dart:convert';
import 'package:seedsphere_core/seedsphere_core.dart' hide TrackerService;
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/scraper_service.dart';
import 'package:router/tracker_service.dart';
import 'package:router/services/ai_service.dart';

/// Distributed Scraper Service
///
/// Delegates scraping to Gardeners via EventService instead of scraping locally.
/// Implements strict "Server Never Scrapes" policy.
class DistributedScraperService extends ScraperService {
  final DbService _db;
  final EventService _events;

  /// Creates a [DistributedScraperService] with the given [trackers] and [aiService].
  DistributedScraperService(
    super.trackers, {
    required super.config,
    required DbService db,
    required EventService events,
    super.aiService,
  }) : _db = db,
       _events = events,
       super(eventService: events);

  @override
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String id,
    Map<String, dynamic> settings, {
    String? userId,
    String? title,
    int? year,
  }) async {
    final decodedId = Uri.decodeComponent(id);
    print('[DistributedScraper] getStreams($type, $decodedId, title=$title, year=$year) for user=$userId');

    // 1. Check Cache (24h)
    final cached = _db.getScrapCache(decodedId);
    if (cached != null) {
      print('[DistributedScraper] Serving cached streams for $decodedId');
      return cached;
    }

    // 2. Metadata Enrichment (Critical for P2P Context)
    String? effectiveTitle = title;
    int? effectiveYear = year;

    if (effectiveTitle == null && decodedId.startsWith('tt')) {
      try {
        // Strip season:episode for Cinemeta metadata fetch (e.g. tt123:1:1 -> tt123)
        final baseId = decodedId.contains(':') ? decodedId.split(':')[0] : decodedId;
        final uri = Uri.parse('https://v3-cinemeta.strem.io/meta/$type/$baseId.json');
        final resp = await httpClient.get(uri).timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final meta = data['meta'];
          if (meta != null) {
            effectiveTitle = meta['name'] ?? meta['title'];
            final releaseInfo = meta['releaseInfo']?.toString();
            if (releaseInfo != null) {
              effectiveYear = int.tryParse(releaseInfo.split('-')[0]);
            }
            print('[DistributedScraper] Enriched metadata from Cinemeta: $effectiveTitle ($effectiveYear)');
          }
        }
      } catch (e) {
        print('[DistributedScraper] Metadata enrichment failed: $e');
      }
    }

    // 3. Check Available Gardeners
    if (userId == null) {
      // Public request? We can't delegate easily without a user context.
      return _informativeStream(
        'Setup Required',
        'Please login to use distributed scraping.',
      );
    }

    // Find active gardeners for this user
    List<Map<String, dynamic>> bindings = [];
    if (userId == 'public') {
      final allClients = _events.getConnectedClients();
      if (allClients.isNotEmpty) {
        bindings = allClients.map((id) => {'device_id': id}).toList();
      }
    } else {
      bindings = _db.getBindings(userId);
    }

    String? targetGardener;
    for (final b in bindings) {
      final gardenerId = b['device_id'];
      if (_events.isConnected(gardenerId)) {
        targetGardener = gardenerId;
        break;
      }
    }

    if (targetGardener == null) {
      print('[DistributedScraper] No active gardener found for user $userId');
      return _informativeStream(
        'Gardener Disconnected',
        'No active Gardener found. Please open the Gardener app.',
      );
    }

    // 3. Delegate Task
    print('[DistributedScraper] Delegating scrape $decodedId to $targetGardener');
    final completer = Completer<List<Map<String, dynamic>>>();
    final taskId = '${DateTime.now().millisecondsSinceEpoch}_$decodedId';

    _pendingTasks[taskId] = completer;

    _events.publish(targetGardener, 'scrape_task', {
      'taskId': taskId,
      'imdbId': decodedId,
      'type': type,
      'title': effectiveTitle,
      'year': effectiveYear,
    });

    try {
      bool timedOut = false;
      final results = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          timedOut = true;
          return <Map<String, dynamic>>[];
        },
      );

      if (timedOut) {
         return _informativeStream(
          'Scrape Timeout',
          'Gardener did not respond in time. Please try again.',
        );
      }

      if (results.isEmpty) {
        return _informativeStream(
          'No Streams Found',
          'No valid streams were resolved by the swarm.',
        );
      }

      final cappedResults = results.length > 40 ? results.take(40).toList() : results;
      _db.setScrapCache(decodedId, cappedResults);
      return cappedResults;
    } catch (e) {
      print('[DistributedScraper] Task error: $e');
      _pendingTasks.remove(taskId);
      return _informativeStream(
        'Scrape Error',
        'An unexpected error occurred during resolution.',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDynamicCatalog(
    String type,
    String query,
    String userId,
  ) async {
    final cacheKey = 'catalog:$userId:$query';
    final cached = _db.getScrapCache(cacheKey);
    if (cached != null) return cached;

    final bindings = _db.getBindings(userId);
    String? targetGardener;
    for (final b in bindings) {
      if (_events.isConnected(b['device_id'])) {
        targetGardener = b['device_id'];
        break;
      }
    }

    if (targetGardener == null) {
      return [
        {
          'id': 'error_no_gardener',
          'type': type,
          'name': '⚠️ Gardener Disconnected',
          'poster': 'https://placehold.co/400x600?text=Disconnected',
          'description': 'Please open SeedSphere on your phone.',
        },
      ];
    }

    final completer = Completer<List<Map<String, dynamic>>>();
    final taskId = 'cat_${DateTime.now().millisecondsSinceEpoch}_$query';
    _pendingTasks[taskId] = completer;

    _events.publish(targetGardener, 'task', {
      'type': 'catalog_prompt',
      'id': taskId,
      'payload': {'query': query, 'mediaType': type},
    });

    try {
      final results = await completer.future.timeout(const Duration(seconds: 15));
      if (results.isNotEmpty) _db.setScrapCache(cacheKey, results);
      return results;
    } catch (e) {
      _pendingTasks.remove(taskId);
      return [
        {
          'id': 'error_timeout',
          'type': type,
          'name': '⚠️ AI Timeout',
          'poster': 'https://placehold.co/400x600?text=Timeout',
          'description': 'The AI took too long to think.',
        },
      ];
    }
  }

  static final Map<String, Completer<List<Map<String, dynamic>>>> _pendingTasks = {};

  /// Called by the Task Result API endpoint to complete a pending scrape task.
  static void handleResult(String taskId, List<Map<String, dynamic>> results) {
    if (_pendingTasks.containsKey(taskId)) {
      _pendingTasks[taskId]!.complete(results);
      _pendingTasks.remove(taskId);
    } else {
      print('[P2P] Received result for unknown/timed-out task: $taskId');
    }
  }

  List<Map<String, dynamic>> _informativeStream(String title, String message) {
    return [
      {
        'title': '⚠️ $title\n$message',
        'infoHash': 'static_error_${title.replaceAll(' ', '_')}',
        'url': 'data:text/plain;charset=utf-8,$message',
        'behaviorHints': {'bingeGroup': 'seedsphere-error'},
      },
    ];
  }
}

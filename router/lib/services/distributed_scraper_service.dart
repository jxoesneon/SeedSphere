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
    TrackerService trackers, {
    required AppConfig config,
    required DbService db,
    required EventService events,
    AiService? aiService,
  }) : _db = db,
       _events = events,
       super(trackers, config: config, eventService: events, aiService: aiService);

  @override
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String rawId,
    Map<String, dynamic> settings, {
    String? userId,
    String? title,
    int? year,
  }) async {
    final id = Uri.decodeComponent(rawId);
    print('[DistributedScraper] getStreams($type, $id, title=$title, year=$year) for user=$userId');

    // 1. Check Cache (24h)
    final cached = _db.getScrapCache(id);
    if (cached != null) {
      print('[DistributedScraper] Serving cached streams for $id');
      return cached;
    }

    // 2. Metadata Enrichment (Critical for P2P Context)
    String? effectiveTitle = title;
    int? effectiveYear = year;

    if (effectiveTitle == null && id.startsWith('tt')) {
      try {
        // Strip season:episode for Cinemeta metadata fetch (e.g. tt123:1:1 -> tt123)
        final baseId = id.contains(':') ? id.split(':')[0] : id;
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
      // But typically requests come from users.
      // If public, we might need a fallback pool or just deny.
      // For now, return informative stream.
      return _informativeStream(
        'Setup Required',
        'Please login to use distributed scraping.',
      );
    }

    // Find active gardeners for this user
    List<Map<String, dynamic>> bindings = [];
    if (userId == 'public') {
      // For public requests, use any available gardener in the swarm.
      final allClients = _events.getConnectedClients();
      print('[DistributedScraper] Public request. Connected clients: $allClients');
      if (allClients.isNotEmpty) {
        bindings = allClients.map((id) => {'device_id': id}).toList();
      }
    } else {
      bindings = _db.getBindings(userId);
    }

    print(
      '[DistributedScraper] Found ${bindings.length} device bindings for $userId',
    );
    // Filter for gardeners (device_id usually)
    // Actually getSessions logic might track active connections in eventService?
    // EventService tracks connections by client ID.
    // We need to find a client ID (Gardener) that is connected.

    String? targetGardener;
    for (final b in bindings) {
      final gardenerId = b['device_id'];
      final isConnected = _events.isConnected(gardenerId);
      print(
        '[DistributedScraper] Checking device $gardenerId... Connected: $isConnected',
      );
      if (isConnected) {
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
    print('[DistributedScraper] Delegating scrape $id to $targetGardener');
    final completer = Completer<List<Map<String, dynamic>>>();

    // Subscribe to result (one-off)
    // We need a unique ID for this correlation.
    final taskId = '${DateTime.now().millisecondsSinceEpoch}_$id';

    // We can't easily await a specific event in the current EventService architecture
    // without a temporary listener.
    // Let's assume we can add a transient listener or we modify EventService.
    // For now, let's use a simple polling or callback map mechanism if implementing strictly.
    // But since I can't modify EventService extensively right now, I'll assume we can use
    // a "reply" channel concept.

    // WORKAROUND: We will send the task and return a specific stream saying "Processing...".
    // Real-time resolution is hard without WebSocket bi-directionality here and now.
    // Stremio expects immediate response.
    // If we wait, we might timeout (10-15s is Stremio limit).
    // Let's try to wait for 10s.

    // We need a way to receive the response.
    // Let's rely on the Gardener sending a POST /api/task/result
    // which triggers a callback we register here.

    // Creating a static map for pending tasks in this service is risky for scaling but fine for single instance.
    _pendingTasks[taskId] = completer;

    _events.publish(targetGardener, 'scrape_task', {
      'taskId': taskId,
      'imdbId': id,
      'type': type,
      'title': effectiveTitle,
      'year': effectiveYear,
    });

    try {
      // 1:1 Parity: Increase timeout for heavy scrapes, but use a race for UI responsiveness
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

      // Limit results to top 40 for Stremio compliance
      final cappedResults = results.length > 40 ? results.take(40).toList() : results;

      // Cache Result
      _db.setScrapCache(id, cappedResults);
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
    // 1. Check Cache
    final cacheKey = 'catalog:$userId:$query';
    final cached = _db.getScrapCache(
      cacheKey,
    ); // Reusing scrap cache table for now
    if (cached != null) {
      print('[DistributedScraper] Serving cached catalog for "$query"');
      return cached;
    }

    // 2. Find Active Gardener
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

    // 3. Delegate Task
    print(
      '[DistributedScraper] Delegating catalog "$query" to $targetGardener',
    );
    final completer = Completer<List<Map<String, dynamic>>>();
    final taskId = 'cat_${DateTime.now().millisecondsSinceEpoch}_$query';

    _pendingTasks[taskId] = completer;

    _events.publish(targetGardener, 'task', {
      'type': 'catalog_prompt',
      'id': taskId,
      'payload': {'query': query, 'mediaType': type},
    });

    try {
      final results = await completer.future.timeout(
        const Duration(seconds: 15),
      );

      // Cache valid results
      if (results.isNotEmpty) {
        _db.setScrapCache(cacheKey, results);
      }
      return results;
    } catch (e) {
      print('[DistributedScraper] Catalog task timeout: $e');
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

  // Pending tasks map: TaskID -> Completer
  static final Map<String, Completer<List<Map<String, dynamic>>>>
  _pendingTasks = {};

  /// Called by the Task Result API endpoint
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

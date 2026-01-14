import 'dart:async';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/scraper_service.dart';

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
  }) async {
    print('[DistributedScraper] getStreams($type, $id) for user=$userId');

    // 1. Check Cache (24h)
    final cached = _db.getScrapCache(id);
    if (cached != null) {
      print('[DistributedScraper] Serving cached streams for $id');
      return cached;
    }

    // 2. Check Available Gardeners
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
    final bindings = _db.getBindings(userId);
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
    });

    try {
      final results = await completer.future.timeout(
        const Duration(seconds: 12),
      );

      // Cache Result
      _db.setScrapCache(id, results);
      return results;
    } catch (e) {
      print('[DistributedScraper] Task timeout or error: $e');
      _pendingTasks.remove(taskId);
      return _informativeStream(
        'Scrape Timeout',
        'Gardener did not respond in time. Please try again.',
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
  static void handleResult(String taskId, List<dynamic> results) {
    if (_pendingTasks.containsKey(taskId)) {
      _pendingTasks[taskId]!.complete(results.cast<Map<String, dynamic>>());
      _pendingTasks.remove(taskId);
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

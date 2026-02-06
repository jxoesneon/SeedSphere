import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/cortex_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final taskExecutorProvider = Provider<TaskExecutorService>((ref) {
  final service = TaskExecutorService(
    ref.read(p2pManagerProvider),
    ref.read(cortexServiceProvider),
  );
  ref.onDispose(() => service.stop());
  return service;
});

/// Listens for scrape tasks from the Router and executes them.
class TaskExecutorService {
  final P2PManager _p2p;
  final ScraperEngine _scraper;
  final CortexService _cortex;
  StreamSubscription? _subscription;
  final ValueNotifier<int> activeTaskCount = ValueNotifier<int>(0);

  TaskExecutorService(this._p2p, this._cortex)
    : _scraper = ScraperEngine.defaults(p2p: _p2p);

  void start() {
    DebugLogger.info(
      'TaskExecutor: Starting service... (Listening to P2P Stream)',
    );
    _subscription = _p2p.eventStream.listen(_handleEvent);
  }

  void stop() {
    _subscription?.cancel();
    DebugLogger.info('TaskExecutor: Stopped.');
  }

  Future<void> _handleEvent(Map<String, dynamic> event) async {
    DebugLogger.debug(
      'TaskExecutor: Received Raw Event: $event',
      category: 'TASK',
    );

    // We expect events from SSE or P2P commands
    // Format from Router: { "type": "scrape_task", "taskId": "...", "imdbId": "...", ... }

    // Note: P2PManager might wrap SSE events.
    // The EventService sends: event: scrape_task\ndata: {...}
    // P2PManager puts the data map directly into the stream if parsed.

    // We check for 'scrape_task' in 'event' field (from SSE) or 'type' (from P2P Cmd)
    // Actually EventService payload is `data`. P2PManager parses `data` into the map.
    // But P2PManager implementation says: `_eventStreamController.add(event)` where event is the jsonDecoded payload.
    // The Router sends `eventService.publish(..., 'scrape_task', payload)`.
    // BUT EventService.publish formats it as `event: scrape_task\ndata: payload`.
    // P2PManager SSE listener parses `data:` lines. It DOES NOT include the event name in the data map unless the router put it there.
    // Wait, let's check P2PManager again.
    // It says: `if (line.startsWith('data:')) { ... _eventStreamController.add(event) ... }`
    // It loses the `event: scrape_task` context unless `event` name is INSIDE the data payload.
    // Checking `DistributedScraperService.dart`...
    // `_events.publish(..., 'scrape_task', { 'taskId': ..., 'imdbId': ..., 'type': ... })`
    // So the payload DOES NOT have "type" or "event_name" field explicitly set to "scrape_task".
    // Wait, `type` is in the payload! But it refers to `stream type` (movie/series).

    // CRITICAL FIX: I need to update DistributedScraperService to include an identifier in the payload
    // so the Gardener knows what kind of event it is.
    // OR P2PManager should pass the event name.
    // P2PManager Logic:
    // It reads `event: ...` line but doesn't store it to pass with `data`.
    // It only triggers on `data:`.
    // So the payload MUST contain the discriminator.

    // Let's assume for now I can infer it from `taskId` presence.
    if (event.containsKey('taskId') && event.containsKey('imdbId')) {
      DebugLogger.info(
        'TaskExecutor: Identified Scrape Task',
        category: 'TASK',
      );
      await _executeScrape(event);
    } else if (event['type'] == 'catalog_prompt') {
      DebugLogger.info(
        'TaskExecutor: Identified Catalog Prompt',
        category: 'TASK',
      );
      await _executeCatalogPrompt(event);
    } else if (event['type'] == 'log') {
      // Just passthrough logs from Router
      DebugLogger.debug(
        'TaskExecutor: Router Log: ${event['message']}',
        category: 'TASK',
      );
    } else {
      DebugLogger.warn(
        'TaskExecutor: Unknown event structure: ${event.keys}',
        category: 'TASK',
      );
    }
  }

  Future<void> _executeCatalogPrompt(Map<String, dynamic> task) async {
    DebugLogger.info(
      'TaskExecutor: Executing Catalog Prompt: $task',
      category: 'AI',
    );
    final taskId = task['id'] as String;
    final payload = task['payload'] as Map<String, dynamic>;
    final query = payload['query'] as String;
    final type = payload['mediaType'] as String? ?? 'movie';

    DebugLogger.info('TaskExecutor: Processing AI Catalog "$query" ($type)...');
    activeTaskCount.value++;

    try {
      // 1. Generate List via Cortex (AI)
      final items = await _cortex.generateCatalog(query, type);

      if (items.isEmpty) {
        DebugLogger.warn('TaskExecutor: AI returned no items for $query');
      } else {
        DebugLogger.info('TaskExecutor: AI returned ${items.length} items.');
      }

      // 2. Resolve to Stremio Metas
      final metas = <Map<String, dynamic>>[];
      for (final item in items) {
        metas.add({
          "id":
              item['imdb_id'] ??
              "tt${DateTime.now().microsecondsSinceEpoch}", // Fallback
          "type": type,
          "name": item['title'],
          "poster": item['poster'],
          "description": item['overview'] ?? "AI Selected",
        });
      }

      await _sendResults(taskId, metas);
    } catch (e) {
      DebugLogger.error('TaskExecutor: AI Catalog failed', error: e);
    } finally {
      activeTaskCount.value = (activeTaskCount.value - 1).clamp(0, 999);
    }
  }

  Future<void> _executeScrape(Map<String, dynamic> task) async {
    DebugLogger.info(
      'TaskExecutor: Executing Scrape Task: $task',
      category: 'SCRAPE',
    );
    final taskId = task['taskId'] as String;
    final imdbId = task['imdbId'] as String;
    // final type = task['type'] as String;

    DebugLogger.info('TaskExecutor: Received scrape task $taskId for $imdbId');

    try {
      // Execute Scrape
      final results = await _scraper.scrapeAll(imdbId);

      DebugLogger.info(
        'TaskExecutor: Scrape complete for $imdbId. Found ${results.length} streams.',
      );

      // Send Results back to Router
      await _sendResults(taskId, results);
    } catch (e) {
      DebugLogger.error('TaskExecutor: Scrape failed', error: e);
      // Optional: Send error result
    }
  }

  Future<void> _sendResults(
    String taskId,
    List<Map<String, dynamic>> results,
  ) async {
    final endpoint = '${NetworkConstants.apiBase}/api/task/result';
    DebugLogger.info(
      'TaskExecutor: Sending results to $endpoint (taskId: $taskId, count: ${results.length})',
      category: 'NET',
    );
    try {
      final resp = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'taskId': taskId, 'results': results}),
      );

      if (resp.statusCode != 200) {
        DebugLogger.warn(
          'TaskExecutor: Failed to submit results (${resp.statusCode}): ${resp.body}',
        );
      } else {
        DebugLogger.info('TaskExecutor: Results submitted successfully.');
      }
    } catch (e) {
      DebugLogger.error('TaskExecutor: Result submission error', error: e);
    }
  }
}

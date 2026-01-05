import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/stream_history_manager.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';

/// A local HTTP server that acts as a Stremio Addon.
///
/// Provides a manifest and handles stream resolution requests from Stremio.
/// When a stream is resolved, it is automatically saved to [StreamHistoryManager].
class StremioServer {
  static final StremioServer _instance = StremioServer._internal();
  factory StremioServer() => _instance;
  StremioServer._internal();

  HttpServer? _server;
  final StreamResolver _resolver = StreamResolver();
  final ScraperEngine _scrapers = ScraperEngine.defaults();
  String? _gardenerId;

  /// Starts the Stremio server on the configured port.
  Future<void> start({String? gardenerId}) async {
    if (_server != null) return;
    _gardenerId = gardenerId;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        NetworkConstants.stremioManifestPort,
      );
      debugPrint(
        'STREMIO: Server listening on port ${NetworkConstants.stremioManifestPort}',
      );

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;

          if (path == '/manifest.json') {
            await _handleManifest(request);
          } else if (path.startsWith('/catalog/')) {
            await _handleCatalog(request);
          } else if (path.startsWith('/stream/')) {
            await _handleStream(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          debugPrint('STREMIO: Error handling request: $e');
        }
      });
    } catch (e) {
      debugPrint('STREMIO: Failed to start server: $e');
    }
  }

  Future<void> _handleManifest(HttpRequest request) async {
    final gardenerId =
        _gardenerId ??
        (NetworkConstants.apiBase.contains('localhost')
            ? 'dev-gardener'
            : 'gardener-generic');

    final manifest = {
      'id': 'org.seedsphere.gardener',
      'version': '2.0.0',
      'name': 'SeedSphere Gardener',
      'description': 'Direct P2P resolution for SeedSphere Swarm.',
      'resources': ['stream', 'catalog'],
      'types': ['movie', 'series'],
      'idPrefixes': ['tt'],
      'catalogs': [
        {
          'id': 'seedsphere.recent',
          'type': 'movie',
          'name': 'SeedSphere: Recently Resolved',
        },
      ],
      'behaviorHints': {'configurable': true, 'configurationRequired': false},
      'configurationURL':
          '${NetworkConstants.apiBase}/configure.html?id=$gardenerId',
    };

    request.response.headers.contentType = ContentType.json;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.write(jsonEncode(manifest));
    await request.response.close();
  }

  Future<void> _handleCatalog(HttpRequest request) async {
    // Path: /catalog/{type}/{id}.json
    final history = await StreamHistoryManager.getHistory();
    final metas = history.map((item) {
      return {
        'id': item['id'],
        'type':
            'movie', // History doesn't strictly track type yet, default to movie
        'name': item['title'] ?? 'Resolved Stream',
        'posterShape': 'poster',
      };
    }).toList();

    request.response.headers.contentType = ContentType.json;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.write(jsonEncode({'metas': metas}));
    await request.response.close();
  }

  Future<void> _handleStream(HttpRequest request) async {
    // Path: /stream/{type}/{id}.json
    final segments = request.uri.pathSegments;
    if (segments.length < 3) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final id = segments[2].replaceAll('.json', '');
    debugPrint('STREMIO: Stream request for ID: $id');

    // 1. Scrape for magnets
    final results = await _scrapers.scrapeAll(id);
    if (results.isEmpty) {
      request.response.write(jsonEncode({'streams': []}));
      await request.response.close();
      return;
    }

    // 2. Take first result as a trial (simplified for now)
    final topResult = results.first;
    final magnet = topResult['magnet'];

    if (magnet == null) {
      request.response.write(jsonEncode({'streams': []}));
      await request.response.close();
      return;
    }

    // 3. Resolve to direct link
    final directUrl = await _resolver.resolveStream(magnet);

    if (directUrl != null) {
      // 4. Log to history
      await StreamHistoryManager.addStream({
        'id': id,
        'title': topResult['title'] ?? 'Resolved Stream',
        'subtitle': topResult['infoHash']?.substring(0, 8) ?? id,
        'source': 'Gardener',
        'magnet': magnet,
        'seeders': topResult['seeders'] ?? 0,
      });

      // 5. Report activity to central Router
      unawaited(
        ActivityManager().reportActivity(
          type: 'stremio',
          title: 'Resolved via Extension: ${topResult['title'] ?? id}',
          meta: {'id': id, 'source': topResult['source'] ?? 'extension'},
        ),
      );

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'streams': [
            {'title': 'SeedSphere Direct', 'url': directUrl},
          ],
        }),
      );
    } else {
      request.response.write(jsonEncode({'streams': []}));
    }

    await request.response.close();
  }

  /// Stops the Stremio server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

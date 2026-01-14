import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

import 'package:router/scraper_service.dart';
import 'package:router/db_service.dart';

/// Service that powers the Stremio Addon functionality.
///
/// Handles manifest generation and stream resolution (redirecting to the Swarm).
class AddonService {
  final ScraperService _scraper;
  final DbService _db;
  final http.Client _client;

  /// Creates a new AddonService.
  AddonService(this._scraper, this._db, [http.Client? client])
    : _client = client ?? http.Client();

  /// Returns the router representing the Stremio Addon routes.
  Router get router {
    final app = Router();

    // Public Manifest (Default)
    app.get('/manifest.json', _handlePublicManifest);

    // Variant Manifest (Legacy Experiments)
    app.get(
      '/manifest.variant.<variant>/manifest.json',
      _handleVariantManifest,
    );
    // Variant Stream
    app.get(
      '/manifest.variant.<variant>/stream/<type>/<id>.json',
      _handleVariantStream,
    );

    // User-Specific Manifest (Thin Client)
    app.get('/u/<userId>/manifest.json', _handleUserManifest);

    // Catalog Handler (Public)
    app.get('/catalog/<type>/<id>.json', _handleCatalog);

    return app;
  }

  /// Generates the manifest map for a user (Public API).
  Future<Map<String, dynamic>> generateManifest(String userId) async {
    final manifest = Map<String, dynamic>.from(_baseManifest);
    manifest['name'] = "SeedSphere (Private)";
    manifest['configurationURL'] =
        "https://seedsphere.app/configure.html"; // Default fallback
    return manifest;
  }

  // Define the base manifest structure
  Map<String, dynamic> get _baseManifest => {
    "id": "community.seedsphere",
    "version": "2.1.5",
    "name": "SeedSphere",
    "description":
        "The Last Media Addon You'll Ever Need. Powered by a community swarm.",
    "logo": "https://seedsphere.app/assets/icon.png",
    "resources": ["catalog", "stream"],
    "types": ["movie", "series", "anime"],
    "idPrefixes": ["tt", "kitsu"],
    "behaviorHints": {"configurationRequired": true, "configurable": true},
    "catalogs": [
      {"type": "movie", "id": "top", "name": "Swarm Popular"},
      {"type": "series", "id": "top", "name": "Swarm Popular"},
    ],
  };

  Response _handlePublicManifest(Request req) {
    final manifest = Map<String, dynamic>.from(_baseManifest);
    final scheme = req.requestedUri.scheme;
    final host = req.requestedUri.host;
    final port = req.requestedUri.port;
    final portString = (port == 80 || port == 443) ? '' : ':$port';
    manifest['configurationURL'] = '$scheme://$host$portString/configure.html';
    return _jsonResponse(manifest);
  }

  /// Handler for catalog requests (Popular content).
  Future<Response> _handleCatalog(Request req, String type, String id) async {
    // Check for Dynamic Catalog
    if (id.startsWith('dynamic:')) {
      final parts = id.split(':');
      // Format: dynamic:<userId>:<query>
      if (parts.length >= 3) {
        final userId = parts[1];
        final query = parts.sublist(2).join(':');

        try {
          final metas = await _scraper.getDynamicCatalog(type, query, userId);
          return _jsonResponse({'metas': metas});
        } catch (e) {
          print('Dynamic Catalog Error: $e');
          return _jsonResponse({'metas': []});
        }
      }
    }

    if (id == 'top' || id == 'top.json') {
      return _proxyCinemeta(type);
    }
    return _jsonResponse({'metas': []});
  }

  /// Proxies the Cinemeta catalog to provide real, dynamic metadata.
  Future<Response> _proxyCinemeta(String type) async {
    try {
      // Cinemeta V3 endpoint for popular movies/series
      final uri = Uri.parse(
        'https://v3-cinemeta.strem.io/catalog/$type/top.json',
      );
      final resp = await _client.get(uri);
      if (resp.statusCode == 200) {
        // Pass-through the real metadata
        return _jsonResponse(jsonDecode(resp.body));
      }
    } catch (e) {
      print('Cinemeta Proxy Error: $e');
    }
    // Fallback if offline
    return _jsonResponse({'metas': []});
  }

  /// Handler for variant manifests (e.g. Lite, Ultra).
  Response _handleVariantManifest(Request req, String variant) {
    final scheme = req.requestedUri.scheme;
    final host = req.requestedUri.host;
    final port = req.requestedUri.port;
    final portString = (port == 80 || port == 443) ? '' : ':$port';

    final manifest = Map<String, dynamic>.from(_baseManifest);
    manifest['configurationURL'] = '$scheme://$host$portString/configure.html';
    manifest['id'] = 'community.seedsphere.$variant';
    manifest['name'] = 'SeedSphere ($variant)';

    // Apply logic
    if (variant == 'lite') {
      manifest['description'] += ' (Lite Mode: No Anime)';
      (manifest['types'] as List).remove('anime');
    }

    return _jsonResponse(manifest);
  }

  /// Handler for variant streams.
  Future<Response> _handleVariantStream(
    Request req,
    String variant,
    String type,
    String id,
  ) async {
    print(
      '[AddonService] Handling Variant Stream Request: variant=$variant, type=$type, id=$id, uri=${req.requestedUri}',
    );
    // Pass variant as a setting to scraper
    final settings = {'variant': variant};
    try {
      final streams = await _scraper.getStreams(type, id, settings);
      return _jsonResponse({'streams': streams});
    } catch (e) {
      print('[AddonService] Variant Stream Error: $e');
      return _jsonResponse({
        'streams': [
          {'name': 'Error', 'title': '$e'},
        ],
      });
    }
  }

  /// Handler for user-specific manifests.
  ///
  /// Currently mirrors the public manifest but allows for future customization
  /// per user (e.g., "SeedSphere (Private)").
  Response _handleUserManifest(Request req, String userId) {
    // 1. Get User Settings
    final user = _db.getUser(userId);
    final settings = user?['settings'] as Map<String, dynamic>? ?? {};

    // 2. Filter Catalogs
    // Settings keys: 'hide_movies', 'hide_series', 'hide_anime'
    var catalogs = List<Map<String, dynamic>>.from(_baseManifest['catalogs']);

    if (settings['hide_movies'] == true) {
      catalogs.removeWhere((c) => c['type'] == 'movie');
    }
    if (settings['hide_series'] == true) {
      catalogs.removeWhere((c) => c['type'] == 'series');
    }
    // Anime is usually a subset of series/movie in Stremio type system,
    // but if we had a specific 'anime' type, we'd filter it.
    // Our base manifest uses standard types.
    // If 'anime' is just a flag for content, we might implement it deeper.
    // For now, let's assume strict type filtering if we add 'anime' type support.

    // Inject Dynamic Catalogs
    final dynamicCatalogs = settings['dynamic_catalogs'] as List?;
    if (dynamicCatalogs != null) {
      for (final query in dynamicCatalogs) {
        if (query is String && query.isNotEmpty) {
          catalogs.add({
            "type": "movie", // Can support series too, or both
            "id": "dynamic:$userId:$query", // Embed userId for routing
            "name": "$query (AI)",
            "extra": [
              {"name": "search", "isRequired": false},
            ], // Just in case
          });
        }
      }
    }

    // 3. Construct Manifest
    final scheme = req.requestedUri.scheme;
    final host = req.requestedUri.host;
    final port = req.requestedUri.port;
    final portString = (port == 80 || port == 443) ? '' : ':$port';

    final manifest = Map<String, dynamic>.from(_baseManifest);
    manifest['name'] = "SeedSphere (Private)";
    manifest['description'] = "Your private swarm gateway.";
    manifest['catalogs'] = catalogs;
    manifest['configurationURL'] = '$scheme://$host$portString/configure.html';

    return _jsonResponse(manifest);
  }

  Response _jsonResponse(Map<String, dynamic> body) {
    return Response.ok(
      jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*', // Critical for Stremio Web
        'Cache-Control': 'max-age=300', // 5 min cache
      },
    );
  }
}

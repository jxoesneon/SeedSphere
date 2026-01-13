import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

import 'package:router/scraper_service.dart';

/// Service that powers the Stremio Addon functionality.
///
/// Handles manifest generation and stream resolution (redirecting to the Swarm).
class AddonService {
  final ScraperService _scraper;
  final http.Client _client;

  /// Creates a new AddonService.
  AddonService(this._scraper, [http.Client? client])
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

  // Define the base manifest structure
  Map<String, dynamic> get _baseManifest => {
    "id": "community.seedsphere",
    "version": "2.1.2",
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
    manifest['configurationURL'] = '$scheme://$host$portString/dashboard.html';
    return _jsonResponse(manifest);
  }

  /// Handler for catalog requests (Popular content).
  Future<Response> _handleCatalog(Request req, String type, String id) async {
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
    manifest['configurationURL'] = '$scheme://$host$portString/dashboard.html';
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
    // Pass variant as a setting to scraper
    final settings = {'variant': variant};
    try {
      final streams = await _scraper.getStreams(type, id, settings);
      return _jsonResponse({'streams': streams});
    } catch (e) {
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
    // We can customize the manifest name to include user details if we want
    // But for now, returning the base manifest is sufficient as the magic happens in /stream
    final scheme = req.requestedUri.scheme;
    final host = req.requestedUri.host;
    final port = req.requestedUri.port;
    final portString = (port == 80 || port == 443) ? '' : ':$port';

    final manifest = Map<String, dynamic>.from(_baseManifest);
    manifest['name'] = "SeedSphere (Private)";
    manifest['configurationURL'] = '$scheme://$host$portString/dashboard.html';
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

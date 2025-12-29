import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:router/db_service.dart';
import 'package:router/scraper_service.dart';

/// Service that powers the Stremio Addon functionality.
///
/// Handles manifest generation and stream resolution (redirecting to the Swarm).
class AddonService {
  final DbService _db;
  final ScraperService _scraper;

  /// Creates a new AddonService.
  AddonService(this._db, this._scraper);

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

    // Stream Handler (User-Specific)
    app.get('/u/<userId>/stream/<type>/<id>.json', _handleUserStream);

    return app;
  }

  // Define the base manifest structure
  Map<String, dynamic> get _baseManifest => {
    "id": "community.seedsphere",
    "version": "2.0.0",
    "name": "SeedSphere",
    "description":
        "The Last Media Addon You'll Ever Need. Powered by a community swarm.",
    "logo": "https://seedsphere.app/assets/icon.png",
    "resources": ["stream"],
    "types": ["movie", "series", "anime"],
    "idPrefixes": ["tt", "kitsu"],
    "catalogs": [],
  };

  Response _handlePublicManifest(Request req) {
    return _jsonResponse(_baseManifest);
  }

  /// Handler for variant manifests (e.g. Lite, Ultra).
  Response _handleVariantManifest(Request req, String variant) {
    final manifest = Map<String, dynamic>.from(_baseManifest);
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
    final manifest = Map<String, dynamic>.from(_baseManifest);
    manifest['name'] = "SeedSphere (Private)";
    return _jsonResponse(manifest);
  }

  /// Resolves streams for a specific [type] (movie/series) and [id].
  ///
  /// Uses the user's settings (from [userId]) to configure the [ScraperService].
  Future<Response> _handleUserStream(
    Request req,
    String userId,
    String type,
    String id,
  ) async {
    try {
      // 1. Fetch User Settings
      final user = _db.getUser(userId);
      if (user == null) {
        // Invalid user, return empty streams or error stream
        return _jsonResponse({
          'streams': [_errorStream("User not found")],
        });
      }

      final settings = user['settings_json'] != null
          ? jsonDecode(user['settings_json'] as String)
          : {};

      // 2. Parse ID (IMDb vs Kitsu)
      // ID parsing is handled by the Scraper Service implementation

      // 3. Invoke Scraper Engine
      // We pass the user settings to the scraper/engine to respect their providers/debrid keys
      final streams = await _scraper.getStreams(type, id, settings);

      return _jsonResponse({'streams': streams});
    } catch (e) {
      print('Stream Error: $e');
      return _jsonResponse({
        'streams': [_errorStream("Error: $e")],
      });
    }
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

  Map<String, dynamic> _errorStream(String message) {
    return {
      'name': 'SeedSphere',
      'title': '⚠️ $message',
      'url': 'data:text/plain;charset=utf-8,Error',
    };
  }
}

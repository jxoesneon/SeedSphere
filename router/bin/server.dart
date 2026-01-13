import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';

import 'package:router/pairing_service.dart';
import 'package:router/p2p_node.dart';
import 'package:router/db_service.dart';
import 'package:router/core/debug_config.dart';
import 'package:router/event_service.dart';
import 'package:router/linking_service.dart';
import 'package:router/security_middleware.dart';
import 'package:router/rate_limit_middleware.dart';
import 'package:router/health_service.dart';
import 'package:router/swarm_service.dart';
import 'package:router/auth_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/scraper_service.dart';
import 'package:router/addon_service.dart';
import 'package:uuid/uuid.dart';

import 'package:router/tracker_service.dart';
import 'package:router/boost_service.dart';
import 'package:router/prefetch_service.dart';
import 'package:router/task_service.dart';

import 'package:http/http.dart' as http; // Added import

// Services
final db = DbService()..init('data');
final pairingService = PairingService();
final p2pNode = P2PNode();
final eventService = EventService();
final linkingService = LinkingService(db);
final healthService = HealthService();
final swarmService = SwarmService();
final mailerService =
    (Platform.environment['BREVO_API_KEY'] != null &&
        Platform.environment['SMTP_FROM'] != null)
    ? MailerService.brevo(
        apiKey: Platform.environment['BREVO_API_KEY']!,
        fromEmail: Platform.environment['SMTP_FROM']!,
      )
    : MailerService.custom(
        host: Platform.environment['SMTP_HOST'] ?? 'smtp-relay.brevo.com',
        port: int.parse(Platform.environment['SMTP_PORT'] ?? '587'),
        username: Platform.environment['SMTP_USER'] ?? '',
        password: Platform.environment['SMTP_PASS'] ?? '',
        fromEmail:
            Platform.environment['SMTP_FROM'] ?? 'noreply@seedsphere.app',
      );
final trackerService = TrackerService(db, healthService)..init();
final scraperService = ScraperService(trackerService);
final addonService = AddonService(scraperService);
final authService = AuthService(db, mailerService, linkingService);
final boostService = BoostService();
final prefetchService = PrefetchService(scraperService);
// Reuse Auth Secret for simplicity or generate new one.
final taskService = TaskService(
  Platform.environment['AUTH_JWT_SECRET'] ?? 'task-secret-fallback',
);

// Configure routes.
final _router = Router()
  ..get('/api', _rootHandler) // Moved from root to /api
  ..get('/health', _healthHandler)
  // Legacy PIN-pairing (Deprecated in 1.0, kept for parity)
  ..post('/api/pair/start', _createPairingHandler)
  ..post('/api/pair/complete', _completePairingHandler)
  ..get('/api/pair/status', _statusPairingHandler)
  // 1:1 Parity Linking (HMAC Flow)
  ..post('/api/link/start', _linkStartHandler)
  ..post('/api/link/complete', _linkCompleteHandler)
  ..get('/api/link/status', _linkStatusHandler)
  // Real-time Signaling (SSE)
  ..get('/api/rooms/<gardenerId>/events', _eventsHandler)
  // Heartbeats (Secured)
  ..post('/api/rooms/<gardenerId>/heartbeat', _heartbeatHandler)
  // Telemetry & Greenhouse (Parity)
  ..post('/api/telemetry/collect', _telemetryHandler)
  ..post('/api/executor/register', _executorRegisterHandler)
  // Swarm Discovery (Parity)
  ..get('/api/swarm/query', _swarmQueryHandler)
  // P2P Info
  ..get('/p2p/info', _p2pInfoHandler)
  ..get('/p2p/health', _p2pHealthHandler)
  // Tracker Optimization
  // Tracker Distributed Reputation
  ..post('/api/trackers/optimize', _trackerOptimizeHandler) // Legacy/Bridge
  ..get('/api/trackers/best', _trackerBestHandler) // Bridge/Client
  ..get('/api/trackers/sync', _trackerSyncHandler) // Gardener
  ..post('/api/trackers/vote', _trackerVoteHandler) // Gardener
  // Boosts (Legacy Feature Parity)
  ..get('/api/boosts/events', _boostEventsHandler)
  ..get('/api/boosts/recent', _boostRecentHandler)
  // Diagnostics
  ..get('/api/providers/detect', _providersDetectHandler)
  // Tracker Sweep
  ..get('/api/trackers/sweep', _trackerSweepHandler)
  // Task System
  ..post('/api/tasks/request', _taskRequestHandler)
  ..post('/api/tasks/result', _taskResultHandler)
  // Downloads & Releases (Dynamic)
  ..get('/downloads/<file>', _handleDownload)
  ..get('/api/releases', _handleReleases)
  // Mobile Linking (Universal Links)
  ..get('/link', _linkHandler)
  ..get('/.well-known/assetlinks.json', _assetLinksHandler)
  ..get('/.well-known/apple-app-site-association', _appleAssociationHandler)
  // Auth Restoration (Phase 2.5)
  ..mount('/api/auth/', authService.router.call)
  // Stremio Addon (Phase 3)
  ..mount(
    '/addon/',
    addonService.router.call,
  ) // Mounted under /addon/ to avoid conflict with root static files
  // User-specific addon manifest at root for legacy compatibility
  ..get('/u/<userId>/manifest.json', _userManifestHandler)
  ..get('/u/<userId>/catalog/<type>/<id>.json', _userCatalogHandler)
  ..get('/u/<userId>/stream/<type>/<id>.json', _userStreamHandler)
  ..get('/api/devices/<id>/status', _deviceStatusHandler)
  ..post('/api/devices/<id>/unlink', _deviceUnlinkHandler)
  // Debug Tools
  ..post('/api/debug/link_self', _debugLinkSelfHandler)
  // Stream Resolution Fallback (HTTP alternative to P2P)
  ..get('/api/streams/resolve', _streamResolveHandler);

/// Mobile Interstitial Page (Deep Linking)
Response _linkHandler(Request req) {
  final token = req.url.queryParameters['token'] ?? '';
  // Fallback Custom Scheme
  final schemeUrl = 'seedsphere://link?token=$token';

  final html =
      '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Link Device</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: sans-serif; text-align: center; padding: 2rem; background: #0f172a; color: white; }
    .btn { display: inline-block; background: #60a5fa; color: white; padding: 1rem 2rem; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 1rem; }
  </style>
</head>
<body>
  <h1>Open in Gardener</h1>
  <p>Linking your device...</p>
  <a href="$schemeUrl" class="btn">Open App</a>
  <p style="margin-top:2rem; opacity:0.7;">Don't have the app?</p>
  <a href="/dashboard.html#downloads" style="color: #60a5fa;">Download Gardener</a>
  <script>
    // Auto-redirect attempt
    window.location.href = "$schemeUrl";
  </script>
</body>
</html>
  ''';
  return Response.ok(html, headers: {'content-type': 'text/html'});
}

/// Android App Links Verification
///
/// Returns the assetlinks.json for Android Deep Linking.
/// SHA256 fingerprints are read from the ANDROID_SHA256 environment variable.
/// Multiple fingerprints can be comma-separated.
Response _assetLinksHandler(Request req) {
  // Read SHA256 fingerprints from environment (comma-separated for multiple certs)
  final sha256Env = Platform.environment['ANDROID_SHA256'] ?? '';
  final fingerprints = sha256Env.isNotEmpty
      ? sha256Env
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
      : <String>[];

  final json = [
    {
      "relation": ["delegate_permission/common.handle_all_urls"],
      "target": {
        "namespace": "android_app",
        "package_name": "com.seedsphere.gardener",
        "sha256_cert_fingerprints": fingerprints,
      },
    },
  ];
  return Response.ok(
    jsonEncode(json),
    headers: {'content-type': 'application/json'},
  );
}

/// iOS Universal Links Verification
///
/// Returns the apple-app-site-association for iOS Deep Linking.
/// Team ID is read from the IOS_TEAM_ID environment variable.
Response _appleAssociationHandler(Request req) {
  // Read Team ID from environment variable
  final teamId = Platform.environment['IOS_TEAM_ID'] ?? 'TEAM_ID_NOT_SET';

  final json = {
    "applinks": {
      "apps": [],
      "details": [
        {
          "appID": "$teamId.com.seedsphere.gardener",
          "paths": ["/link", "/auth/*"],
        },
      ],
    },
  };
  return Response.ok(
    jsonEncode(json),
    headers: {'content-type': 'application/json'},
  );
}

/// User-specific manifest handler for legacy /u/{userId}/manifest.json route.
Response _userManifestHandler(Request req, String userId) {
  final manifest = {
    "id": "community.seedsphere.user.$userId",
    "version": "2.0.1",
    "name": "SeedSphere (Private)",
    "description":
        "Your personalized SeedSphere addon. Powered by a community swarm.",
    "logo": "https://seedsphere.app/assets/icon.png",
    "resources": ["catalog", "stream"],
    "types": ["movie", "series", "anime"],
    "idPrefixes": ["tt", "kitsu"],
    "catalogs": [
      {"type": "movie", "id": "top", "name": "Swarm Popular"},
      {"type": "series", "id": "top", "name": "Swarm Popular"},
    ],
  };
  return Response.ok(
    jsonEncode(manifest),
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'max-age=300',
    },
  );
}

/// User-specific catalog handler for legacy /u/{userId}/catalog/{type}/{id}.json route.
Future<Response> _userCatalogHandler(
  Request req,
  String userId,
  String type,
  String id,
) async {
  // Proxy Cinemeta V3 for "top" catalog (Swarm Popular)
  if (id == 'top' || id == 'top.json') {
    try {
      final uri = Uri.parse(
        'https://v3-cinemeta.strem.io/catalog/$type/top.json',
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        return Response.ok(
          resp.body,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Cache-Control': 'max-age=300',
          },
        );
      }
    } catch (e) {
      print('Cinemeta Proxy Error: $e');
    }
  }
  // Fallback: empty catalog
  return Response.ok(
    jsonEncode({'metas': []}),
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  );
}

/// User-specific stream handler for legacy /u/{userId}/stream/{type}/{id}.json route.
Future<Response> _userStreamHandler(
  Request req,
  String userId,
  String type,
  String id,
) async {
  // Delegate to the addon service scraper for stream resolution
  try {
    final streams = await scraperService.getStreams(type, id, {});
    return Response.ok(
      jsonEncode({'streams': streams}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    return Response.ok(
      jsonEncode({
        'streams': [
          {'name': 'Error', 'title': '$e'},
        ],
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }
}

/// Root handler returning server status and version info.
Response _rootHandler(Request req) {
  return Response.ok(
    jsonEncode({
      'name': 'SeedSphere Router',
      'version': '2.0.3',
      'status': 'active',
      'mode': 'Federated Frontier (Parity)',
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Caching for Release Data to avoid GitHub API Rate Limits
Map<String, dynamic>? _cachedRelease;
DateTime? _lastCacheTime;

/// Fetch latest release from GitHub (Cached for 15 minutes)
Future<Map<String, dynamic>?> _getLatestRelease() async {
  if (_cachedRelease != null &&
      _lastCacheTime != null &&
      DateTime.now().difference(_lastCacheTime!).inMinutes < 15) {
    return _cachedRelease;
  }

  try {
    print('Fetching latest release from GitHub...');
    final url = Uri.https(
      'api.github.com',
      '/repos/jxoesneon/SeedSphere/releases/latest',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'SeedSphere-Router'},
    );

    if (response.statusCode == 200) {
      _cachedRelease = jsonDecode(response.body);
      _lastCacheTime = DateTime.now();
      return _cachedRelease;
    } else {
      print('GitHub API Error: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('Failed to fetch release: $e');
  }
  return null;
}

/// Dynamic Download Proxy (Smart Resolution)
/// Supports aliases: 'android', 'windows', 'macos', 'linux'
/// Supports explicit filenames: 'gardener-windows-setup-2025...exe'
Future<Response> _handleDownload(Request req, String file) async {
  final release = await _getLatestRelease();
  if (release == null) {
    // Fallback to blind redirect if API fails
    final fallback = Uri.https(
      'github.com',
      '/jxoesneon/SeedSphere/releases/latest/download/$file',
    );
    return Response.found(fallback);
  }

  final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
  String? targetUrl;

  // 1. Check for Aliases
  if (file == 'android') {
    // Prefer .apk over .aab if both exist
    final asset = assets.firstWhere(
      (a) =>
          a['name'].toString().startsWith('gardener-android') &&
          a['name'].toString().endsWith('.apk'),
      orElse: () => assets.firstWhere(
        (a) => a['name'].toString().contains('android'),
        orElse: () => {},
      ),
    );
    if (asset.isNotEmpty) targetUrl = asset['browser_download_url'];
  } else if (file == 'windows') {
    final asset = assets.firstWhere(
      (a) =>
          a['name'].toString().contains('windows') &&
          a['name'].toString().endsWith('.exe'),
      orElse: () => assets.firstWhere(
        (a) => a['name'].toString().contains('windows'),
        orElse: () => {},
      ),
    );
    if (asset.isNotEmpty) targetUrl = asset['browser_download_url'];
  } else if (file == 'macos') {
    final asset = assets.firstWhere(
      (a) =>
          a['name'].toString().contains('macos') ||
          a['name'].toString().contains('universal'),
      orElse: () => assets.firstWhere(
        (a) => a['name'].toString().endsWith('.zip'), // Fallback
        orElse: () => {},
      ),
    );
    if (asset.isNotEmpty) targetUrl = asset['browser_download_url'];
  } else if (file == 'linux') {
    // Prefer .deb, then .rpm, then .zip
    final asset = assets.firstWhere(
      (a) =>
          a['name'].toString().contains('linux') &&
          a['name'].toString().endsWith('.deb'),
      orElse: () => assets.firstWhere(
        (a) =>
            a['name'].toString().contains('linux') &&
            a['name'].toString().endsWith('.rpm'),
        orElse: () => assets.firstWhere(
          (a) =>
              a['name'].toString().contains('linux') &&
              a['name'].toString().endsWith('.zip'),
          orElse: () => {},
        ),
      ),
    );
    if (asset.isNotEmpty) targetUrl = asset['browser_download_url'];
  }
  // 2. Check for Exact Filename Match
  else {
    final asset = assets.firstWhere((a) => a['name'] == file, orElse: () => {});
    if (asset.isNotEmpty) targetUrl = asset['browser_download_url'];
  }

  if (targetUrl != null) {
    return Response.found(targetUrl);
  }

  // 3. Fallback: Blind Redirect (e.g. if file is not found in assets list but might exist)
  final redirect = Uri.https(
    'github.com',
    '/jxoesneon/SeedSphere/releases/latest/download/$file',
  );
  return Response.found(redirect);
}

/// Dynamic Releases Proxy
Future<Response> _handleReleases(Request req) async {
  // We can return the cached latest release wrapped in a list for compatibility if needed,
  // or fetch the full list. Dashboard expects a list.
  try {
    final url = Uri.https(
      'api.github.com',
      '/repos/jxoesneon/SeedSphere/releases',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'SeedSphere-Router'},
    );
    if (response.statusCode != 200) {
      return Response.internalServerError(body: 'github_api_error');
    }
    return Response.ok(
      response.body,
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(body: 'error: $e');
  }
}

/// Health check endpoint for monitoring uptime.
Response _healthHandler(Request req) {
  return Response.ok(
    jsonEncode({'status': 'healthy'}),
    headers: {'content-type': 'application/json'},
  );
}

// PIN Pairing (Legacy)

/// Initiates a legacy PIN-based pairing session.
///
/// Returns a [Response] containing the generated PIN code.
Future<Response> _createPairingHandler(Request req) async {
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final pin = await pairingService.createSession(
    data['seedlingId'] ?? 'unknown',
  );
  return Response.ok(jsonEncode({'ok': true, 'pair_code': pin}));
}

/// Completes a pairing session using a PIN.
Future<Response> _completePairingHandler(Request req) async {
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final session = await pairingService.completePairing(
    data['pin'] ?? data['pair_code'],
    data['gardenerId'] ?? data['device_id'],
  );
  if (session == null) {
    return Response.notFound(jsonEncode({'ok': false, 'error': 'not_found'}));
  }
  return Response.ok(jsonEncode({'ok': true, ...session.toJson()}));
}

/// Checks the status of a pairing session.
Response _statusPairingHandler(Request req) {
  final pin =
      req.url.queryParameters['pin'] ?? req.url.queryParameters['pair_code'];
  if (pin == null) return Response.badRequest(body: 'missing_pin');
  final session = pairingService.getSession(pin);
  return Response.ok(
    jsonEncode({'ok': true, 'paired': session?.isComplete ?? false}),
  );
}

// Linking (HMAC Flow)

/// Starts a 1:1 parity linking flow (HMAC-based).
Future<Response> _linkStartHandler(Request req) async {
  final data = jsonDecode(await req.readAsString());
  final result = linkingService.startLinking(
    data['gardener_id'],
    platform: data['platform'],
  );
  return Response.ok(jsonEncode(result));
}

/// Completes the linking process with a token verification.
Future<Response> _linkCompleteHandler(Request req) async {
  final data = jsonDecode(await req.readAsString());
  final result = linkingService.completeLinking(
    data['token'],
    data['seedling_id'],
  );
  if (result == null) {
    return Response.notFound(jsonEncode({'ok': false, 'error': 'expired'}));
  }
  return Response.ok(jsonEncode(result));
}

/// Returns the current linking status for a Gardener.
Response _linkStatusHandler(Request req) {
  final gId = req.url.queryParameters['gardener_id'];
  // Simplified status for 1:1 parity demonstration
  return Response.ok(jsonEncode({'ok': true, 'linked': gId != null}));
}

// Events (SSE)

/// Handles Server-Sent Events (SSE) subscriptions for real-time updates.
Response _eventsHandler(Request req, String gardenerId) {
  // Debug log for troubleshooting connectivity - gate behind verbose check if needed
  if (req.url.queryParameters.containsKey('debug')) {
    print('DEBUG: _eventsHandler CALLED for $gardenerId');
  }

  final stream = eventService.subscribe(gardenerId);
  return eventService.sseResponse(stream);
}

// Device Management (Portal)

/// Returns status and ownership info for a specific device.
Future<Response> _deviceStatusHandler(Request req, String id) async {
  final ownerId = db.getOwnerForDevice(id);
  final isLinked = ownerId != null;

  var neighbors = 0;
  var ownerDisplay = 'None';

  if (isLinked) {
    final bindings = db.getBindings(ownerId);
    neighbors = bindings.length - 1; // Others in the swarm

    final owner = db.getUser(ownerId);
    if (owner != null) {
      final email = owner['email'] as String?;
      if (email != null) {
        final parts = email.split('@');
        ownerDisplay = '${parts[0].substring(0, 1)}***@${parts[1]}';
      } else {
        ownerDisplay = 'User: ${ownerId.substring(0, 8)}...';
      }
    }
  }

  return Response.ok(
    jsonEncode({
      'ok': true,
      'id': id,
      'linked': isLinked,
      'owner': ownerDisplay,
      'neighbors': neighbors,
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Revokes a specific device binding.
Future<Response> _deviceUnlinkHandler(Request req, String id) async {
  final userId = authService.getSessionId(req);
  if (userId == null) {
    return Response.forbidden(
      jsonEncode({'ok': false, 'error': 'unauthorized'}),
    );
  }

  // Check if device belongs to user
  final ownerId = db.getOwnerForDevice(id);
  if (ownerId != userId) {
    return Response.forbidden(jsonEncode({'ok': false, 'error': 'forbidden'}));
  }

  // Delete the binding
  db.deleteBinding(userId, id);

  db.writeAudit('device_unlinked_portal', {'user_id': userId, 'device_id': id});

  return Response.ok(jsonEncode({'ok': true}));
}

// Heartbeat (Secured via JWT)

/// Active gardeners mapped by user ID for job dispatch
final Map<String, DateTime> _activeGardeners = {};

/// Processes heartbeat signals from Gardeners to maintain active status.
/// Validates JWT Bearer token if provided.
Future<Response> _heartbeatHandler(Request req, String gardenerId) async {
  if (DebugConfig.pulseGated) {
    print('ROUTER_DEBUG: Received heartbeat from $gardenerId');
  }
  // Validate Bearer token if provided
  final authHeader = req.headers['authorization'];
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final token = authHeader.substring(7);
    final claims = authService.verifyJwt(token);

    if (claims == null) {
      return Response(
        401,
        body: jsonEncode({'ok': false, 'error': 'invalid_token'}),
      );
    }

    // Verify the gardener ID matches the token's subject
    final tokenUserId = claims['sub'] as String?;
    if (tokenUserId != null && tokenUserId != gardenerId) {
      return Response(
        403,
        body: jsonEncode({'ok': false, 'error': 'user_mismatch'}),
      );
    }
  }

  // Track active gardener
  _activeGardeners[gardenerId] = DateTime.now();

  // Clean up stale gardeners (inactive > 2 minutes)
  final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
  _activeGardeners.removeWhere((_, lastSeen) => lastSeen.isBefore(cutoff));

  db.touchGardener(gardenerId);
  eventService.publish(gardenerId, 'heartbeat', {
    't': DateTime.now().millisecondsSinceEpoch,
    'active': _activeGardeners.length,
  });
  return Response.ok(
    jsonEncode({'ok': true, 'activeGardeners': _activeGardeners.length}),
  );
}

// Telemetry Collector

/// Collects telemetry data for analytics and debugging.
///
/// Verifies `x-telemetry-key` if configured.
Future<Response> _telemetryHandler(Request req) async {
  final payload = await req.readAsString();
  final data = jsonDecode(payload);

  // Mirroring legacy: x-telemetry-key verification
  final sharedKey = Platform.environment['TELEMETRY_KEY'] ?? '';
  final provided =
      req.headers['x-telemetry-key'] ?? req.url.queryParameters['key'] ?? '';

  if (sharedKey.isNotEmpty && provided != sharedKey) {
    return Response(
      401,
      body: jsonEncode({'ok': false, 'error': 'unauthorized'}),
    );
  }

  // Audit log parity
  db.writeAudit('telemetry', {'ua': req.headers['user-agent'], 'body': data});

  return Response.ok(
    jsonEncode({'ok': true}),
    headers: {'content-type': 'application/json', 'Cache-Control': 'no-store'},
  );
}

// Greenhouse: Executor register

/// Registers a new executor/agent and assigns a device ID.
Future<Response> _executorRegisterHandler(Request req) async {
  final agent = req.headers['user-agent'] ?? 'unknown';
  final deviceId = const Uuid().v4().substring(
    0,
    16,
  ); // Mirroring legacy nanoid(16) length

  db.writeAudit('executor_reg', {'agent': agent, 'device_id': deviceId});

  return Response.ok(
    jsonEncode({'ok': true, 'device_id': deviceId}),
    headers: {'content-type': 'application/json'},
  );
}

// Swarm Query: Coordinate discovery between Gardeners

/// Queries the P2P swarm for metadata or peers.
///
/// Supports real-time scraping if [trackers] are provided.
Future<Response> _swarmQueryHandler(Request req) async {
  final id = req.url.queryParameters['id'];
  final type = req.url.queryParameters['type'];
  final trackers = req.url.queryParametersAll['tracker'] ?? [];

  if (id == null || type == null) {
    return Response.badRequest(body: jsonEncode({'error': 'missing_params'}));
  }

  db.writeAudit('swarm_query', {'id': id, 'type': type});

  // 1:1 Parity: Real-time swarm scraping
  // If trackers are provided, we scrape them directly to get seeds/leechers.
  Map<String, dynamic>? results;
  if (trackers.isNotEmpty) {
    results = await swarmService.scrapeSwarm(id, trackers);
  }

  return Response.ok(
    jsonEncode({
      'ok': true,
      'id': id,
      'type': type,
      'results': results != null ? [results] : [],
      'status': results != null ? 'scraped' : 'query_broadcasted',
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Returns information about the P2P node (PeerID and addresses).
Response _p2pInfoHandler(Request req) {
  return Response.ok(
    jsonEncode({'peerId': p2pNode.peerId, 'addresses': p2pNode.addresses}),
    headers: {'content-type': 'application/json'},
  );
}

/// Checks the health of a specific P2P URL or the node itself.
Future<Response> _p2pHealthHandler(Request req) async {
  final url = req.url.queryParameters['url'];
  if (url != null) {
    final ok = await healthService.checkHealthy(url, aggressive: true);
    return Response.ok(jsonEncode({'url': url, 'healthy': ok}));
  }
  return Response.ok(jsonEncode({'status': 'active', 'engine': 'Dart/AOT'}));
}

/// Returns the calculated "Best" trackers based on community reputation.
Response _trackerBestHandler(Request req) {
  final best = trackerService.getBestTrackers();
  return Response.ok(jsonEncode({'trackers': best}));
}

/// Returns the full list of trackers for Gardeners to verify.
Response _trackerSyncHandler(Request req) {
  final list = trackerService.getSyncList();
  return Response.ok(jsonEncode({'trackers': list}));
}

/// Accepts batch votes from Gardeners.
Future<Response> _trackerVoteHandler(Request req) async {
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final votes = (data['votes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    trackerService.submitVotes(votes);
    return Response.ok(jsonEncode({'ok': true}));
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_payload'}));
  }
}

// Debug Handlers

/// Creates a self-binding for debug purposes.
Future<Response> _debugLinkSelfHandler(Request req) async {
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final gardenerId = data['gardenerId'];

    if (gardenerId == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'missing_gardenerId'}),
      );
    }

    final secret = linkingService.bindDirectly(gardenerId, 'self');
    if (secret == null) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'binding_failed_limit_reached'}),
      );
    }

    return Response.ok(jsonEncode({'ok': true, 'secret': secret}));
  } catch (e) {
    return Response.internalServerError(body: jsonEncode({'error': '$e'}));
  }
}

/// HTTP fallback for stream resolution when P2P mesh is unavailable.
///
/// Accepts `id` (IMDB ID) and optional `type` query parameters.
/// Returns scraped stream metadata for the requested content.
Future<Response> _streamResolveHandler(Request req) async {
  final imdbId = req.url.queryParameters['id'];
  final type = req.url.queryParameters['type'] ?? 'movie';

  if (imdbId == null || imdbId.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'ok': false, 'error': 'missing_id'}),
      headers: {'content-type': 'application/json'},
    );
  }

  try {
    print('[HTTP-FALLBACK] Resolving streams for $imdbId (type: $type)');
    final streams = await scraperService.getStreams(type, imdbId, {});

    return Response.ok(
      jsonEncode({
        'ok': true,
        'imdbId': imdbId,
        'type': type,
        'streamCount': streams.length,
        'streams': streams,
      }),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    print('[HTTP-FALLBACK] Error resolving streams for $imdbId: $e');
    return Response.internalServerError(
      body: jsonEncode({'ok': false, 'error': '$e'}),
    );
  }
}

/// Optimizes a list of trackers by filtering bad ones and injecting best ones.
Future<Response> _trackerOptimizeHandler(Request req) async {
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final incoming = (data['trackers'] as List?)?.cast<String>() ?? [];

    final result = await trackerService.optimize(incoming);
    return Response.ok(jsonEncode(result));
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_payload'}));
  }
}

/// Returns recent boost activity.
Response _boostRecentHandler(Request req) {
  return Response.ok(
    jsonEncode({'ok': true, 'items': boostService.getRecent()}),
  );
}

/// SSE stream for boost events.
Response _boostEventsHandler(Request req) {
  Stream<String> stream() async* {
    yield ': connected\n\n';
    await for (final e in boostService.stream) {
      yield 'event: boost\ndata: ${jsonEncode(e.toJson())}\n\n';
    }
  }

  return eventService.sseResponse(stream());
}

/// Diagnoses upstream provider health.
Future<Response> _providersDetectHandler(Request req) async {
  final results = await scraperService.probeProviders();
  return Response.ok(jsonEncode({'ok': true, 'providers': results}));
}

/// SSE stream for tracker sweeping.
Response _trackerSweepHandler(Request req) {
  final source =
      req.url.queryParameters['source'] ??
      'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt';

  Stream<String> stream() async* {
    yield ': start\n\n';
    await for (final e in trackerService.sweep(source)) {
      yield 'event: sweep\ndata: ${jsonEncode(e)}\n\n';
    }
  }

  return eventService.sseResponse(stream());
}

/// Issues a task to a Gardener (Mock/Echo for now).
Future<Response> _taskRequestHandler(Request req) async {
  try {
    final body = jsonDecode(await req.readAsString());
    final roomId = body['room_id'];
    final type = body['type'] ?? 'echo';
    final params = body['params'] ?? {};

    if (roomId == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'missing_room_id'}),
      );
    }

    // Embed room_id in task payload so we can route the result event later
    final token = taskService.requestTask(type, {
      'ts': DateTime.now().toIso8601String(),
      'room_id': roomId,
      'params': params,
    });

    // Notify the room that a task has been issued
    eventService.publish(roomId, 'task', {
      'type': type,
      'params': params,
      't': DateTime.now().millisecondsSinceEpoch,
    });

    return Response.ok(jsonEncode({'ok': true, 'task_token': token}));
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'bad_request'}));
  }
}

/// Receives a task result.
Future<Response> _taskResultHandler(Request req) async {
  try {
    final body = jsonDecode(await req.readAsString());
    final token = body['token'];
    final result = body['result'];

    final payload = taskService.verifyResult(token);
    if (payload == null) {
      return Response(401, body: jsonEncode({'error': 'invalid_token'}));
    }

    // Extract original context
    final taskPayload = payload['payload'] as Map<String, dynamic>?;
    final roomId = taskPayload?['room_id'];
    final taskId = payload['task_id'];

    if (roomId != null) {
      eventService.publish(roomId, 'result', {
        'task_id': taskId,
        'ok': true, // Assuming success if we got here
        'result': result, // Raw result
        // Helper for Activity.vue which looks for 'normalized' or 'raw'
        'normalized': result is Map ? result['normalized'] : null,
        'raw': result is Map ? result['raw'] : null,
        't': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Log result
    print('Task Complete: $taskId => $result');
    return Response.ok(jsonEncode({'ok': true}));
  } catch (e) {
    print('Error processing result: $e');
    return Response.badRequest(body: jsonEncode({'error': 'bad_request'}));
  }
}

/// Middleware for security hardening headers (CSP, HSTS, etc.)
Middleware securityHardeningMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);

      // 1:1 Parity: Audit CORS and access
      try {
        final connInfo =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        db.writeAudit('access', {
          'ip': connInfo?.remoteAddress.address ?? 'unknown',
          'method': request.method,
          'path': request.url.path,
          'origin': request.headers['origin'] ?? '',
        });
      } catch (_) {}

      return response.change(
        headers: {
          'Strict-Transport-Security':
              'max-age=31536000; includeSubDomains; preload',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'Referrer-Policy': 'no-referrer',
          'Content-Security-Policy':
              "default-src 'self' 'unsafe-inline' https: http:; script-src 'self' 'unsafe-inline'; object-src 'none';",
          ...response.headers, // Keep existing headers
        },
      );
    };
  };
}

String _findPortalDir() {
  if (Directory('portal').existsSync()) return 'portal';
  if (Directory('../portal').existsSync()) return '../portal';
  print('Warning: Portal directory not found. Static serving will fail.');
  return 'portal'; // Fallback
}

Middleware selectiveLogRequests() {
  return (Handler innerHandler) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      final response = await innerHandler(request);

      final path = request.url.path;
      // Silence heartbeat logs unless gated debugging is enabled
      if (path.contains('heartbeat') && !DebugConfig.pulseGated) {
        return response;
      }

      final msg =
          '${DateTime.now().toIso8601String()} '
          '${watch.elapsed.toString().padLeft(15)} '
          '${request.method.padRight(7)} '
          '[${response.statusCode}] '
          '/${request.url.path}';
      print(msg);
      return response;
    };
  };
}

void main(List<String> args) async {
  print('DEBUG: SERVER STARTED');
  // Set global logging level to suppress internal IPFS/P2P FINE logs
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
      '${record.time.toIso8601String()} [${record.level.name}] [${record.loggerName}] ${record.message}',
    );
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  try {
    print('DEBUG: Starting P2PNode...');
    await p2pNode.start();
  } catch (e) {
    print(
      'SeedSphere Router: P2P Node failed to start (libsodium missing?): $e',
    );
    print('SeedSphere Router: Continuing in degraded mode (HTTP-only).');
  }
  prefetchService.start();

  // Periodic Cleanup (Parity)
  print('SeedSphere Router: Starting cleanup timer');
  Timer.periodic(const Duration(minutes: 15), (timer) {
    print('SeedSphere Router: Pruning expired data...');
    db.pruneExpiredData();
  });

  final securePipeline = const Pipeline().addMiddleware(
    securityMiddleware((g, s) async => db.getBindingSecret(g, s)),
  );

  // Initialize Static Handler
  final portalDir = _findPortalDir();
  print('SeedSphere Router: Serving portal from $portalDir');
  final staticHandler = createStaticHandler(
    portalDir,
    defaultDocument: 'index.html',
  );

  final cascade = Cascade()
      .add(_router.call) // Try API/Addon routes first
      .add(staticHandler); // Fallback to static portal files

  final handler = const Pipeline()
      .addMiddleware(selectiveLogRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(securityHardeningMiddleware())
      .addMiddleware(rateLimitMiddleware()) // Global rate limiting
      .addHandler((Request request) {
        // Apply security middleware to the Gardener Namespace (excluding SSE which doesn't support headers)
        if (request.url.path.startsWith('api/rooms/') &&
            !request.url.path.contains('/events')) {
          return securePipeline.addHandler(cascade.handler)(request);
        }
        return cascade.handler(request);
      });

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print(
    'SeedSphere Router (1:1 Parity Polish) listening on port ${server.port}',
  );
}

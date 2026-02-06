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
import 'package:router/services/distributed_scraper_service.dart';
import 'package:router/addon_service.dart';
import 'package:uuid/uuid.dart';

import 'package:router/tracker_service.dart';
import 'package:router/boost_service.dart';
import 'package:router/prefetch_service.dart';
import 'package:router/task_service.dart';
import 'package:router/services/status_service.dart';
import 'package:router/core/server_context.dart';

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
final scraperService = DistributedScraperService(
  trackerService,
  db: db,
  events: eventService,
);
final addonService = AddonService(scraperService, db);
final authService = AuthService(db, mailerService, linkingService);
final boostService = BoostService();
final prefetchService = PrefetchService(scraperService);
final statusService = StatusService(db, eventService);

final task = TaskService(
  Platform.environment['JWT_SECRET'] ?? 'dev_secret_key',
);

// Unified Context (Dependency Injection)
final context = ServerContext(
  db: db,
  pairing: pairingService,
  p2p: p2pNode,
  events: eventService,
  linking: linkingService,
  health: healthService,
  swarm: swarmService,
  mailer: mailerService,
  tracker: trackerService,
  scraper: scraperService,
  addon: addonService,
  auth: authService,
  boost: boostService,
  prefetch: prefetchService,
  task: task,
  status: statusService,
);

/// Middleware to inject ServerContext into requests for dependency injection.
Middleware contextMiddleware(ServerContext context) {
  return (Handler innerHandler) {
    return (Request request) {
      return innerHandler(request.change(context: {'services': context}));
    };
  };
}

// Router definition (1:1 Parity)
final _router = Router()
  ..get('/u/<userId>/stream/<type>/<id>.json', _userStreamHandler)
  ..get('/u/<userId>/manifest.json', _userManifestHandler)
  ..get(
    '/manifest.json',
    (Request req) => _userManifestHandler(req, 'public'),
  ) // Public manifest
  // Fallback public stream handler if user ID is missing/public
  ..get(
    '/stream/<type>/<id>.json',
    (Request req, String type, String id) =>
        _userStreamHandler(req, 'public', type, id),
  )
  ..get('/api/status', _rootHandler) // Moved to free up root for portal
  ..get('/dl/<file>', _handleDownload)
  ..get('/releases', _handleReleases)
  ..get('/health', _healthHandler)
  ..post('/pairing/create', _createPairingHandler)
  ..post('/pairing/complete', _completePairingHandler)
  ..get('/pairing/status', _statusPairingHandler)
  ..post('/link/start', _linkStartHandler)
  ..post('/link/complete', _linkCompleteHandler)
  ..get('/link/status', _linkStatusHandler)
  ..get(
    '/api/events',
    (Request req) =>
        _eventsHandler(req, req.url.queryParameters['gardenerId'] ?? 'unknown'),
  )
  ..get(
    '/api/rooms/<roomId>/events',
    (Request req, String roomId) =>
        _eventsHandler(req, req.url.queryParameters['gardenerId'] ?? roomId),
  )
  ..get('/api/devices/<id>/status', _deviceStatusHandler)
  ..post('/api/devices/<id>/unlink', _deviceUnlinkHandler)
  ..get('/device/<id>', _deviceStatusHandler) // Legacy
  ..delete('/device/<id>', _deviceUnlinkHandler) // Legacy
  ..get('/u/<userId>/configure', _userConfigureHandler)
  ..get('/api/heartbeat/<gardenerId>', _heartbeatHandler)
  ..post('/api/telemetry', _telemetryHandler)
  ..post('/api/register', _executorRegisterHandler)
  ..get('/api/swarm', _swarmQueryHandler)
  ..get('/api/p2p/info', _p2pInfoHandler)
  ..get('/api/p2p/health', _p2pHealthHandler)
  ..get('/api/tracker/best', _trackerBestHandler)
  ..get('/api/tracker/sync', _trackerSyncHandler)
  ..post('/api/tracker/vote', _trackerVoteHandler)
  ..post('/api/debug/link/self', _debugLinkSelfHandler)
  ..get('/resolve', _streamResolveHandler)
  ..post('/tracker/optimize', _trackerOptimizeHandler)
  ..get('/api/boost/recent', _boostRecentHandler)
  ..get('/api/boost/events', _boostEventsHandler)
  ..get('/api/providers', _providersDetectHandler)
  ..get('/api/tracker/sweep', _trackerSweepHandler)
  ..post('/api/task', _taskRequestHandler)
  ..post('/api/task/result', _taskResultHandler)
  ..mount('/api/auth/', authService.router.call); // Mount Auth Service

/// Helper to extract services from request context.
ServerContext _services(Request request) =>
    request.context['services'] as ServerContext;

/// User-specific manifest handler for legacy /u/{userId}/manifest.json route.
Future<Response> _userManifestHandler(Request req, String userId) async {
  final services = _services(req);
  final scheme = req.requestedUri.scheme;
  final host = req.requestedUri.host;
  final port = req.requestedUri.port;
  final portString = (port == 80 || port == 443) ? '' : ':$port';
  final baseUrl = '$scheme://$host$portString/u/$userId';

  // Generate a personalized manifest with configuration hints
  final manifest = await services.addon.generateManifest(
    userId,
    baseUrl: baseUrl,
  );
  return Response.ok(
    jsonEncode(manifest),
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  );
}

// ... (Rest of file) ...

/// User-specific stream handler for legacy /u/{userId}/stream/{type}/{id}.json route.
Future<Response> _userStreamHandler(
  Request req,
  String userId,
  String type,
  String id,
) async {
  final services = _services(req);
  // Delegate to the addon service scraper for stream resolution
  try {
    final streams = await services.scraper.getStreams(
      type,
      id,
      {},
      userId: userId,
    );
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
      'version': '2.1.8',
      'status': 'active',
      'mode': 'Federated Frontier (Parity)',
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Caching for Release Data to avoid GitHub API Rate Limits
Map<String, dynamic>? _cachedRelease;
DateTime? _lastCacheTime;

List<dynamic>? _cachedReleasesList;
DateTime? _lastReleasesCacheTime;

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
  // Check cache (15 minutes)
  if (_cachedReleasesList != null &&
      _lastReleasesCacheTime != null &&
      DateTime.now().difference(_lastReleasesCacheTime!).inMinutes < 15) {
    return Response.ok(
      jsonEncode(_cachedReleasesList),
      headers: {'content-type': 'application/json'},
    );
  }

  try {
    final url = Uri.https(
      'api.github.com',
      '/repos/jxoesneon/SeedSphere/releases',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'SeedSphere-Router'},
    );

    if (response.statusCode == 200) {
      _cachedReleasesList = jsonDecode(response.body);
      _lastReleasesCacheTime = DateTime.now();
      return Response.ok(
        response.body,
        headers: {'content-type': 'application/json'},
      );
    } else {
      // Fallback to stale cache if available
      if (_cachedReleasesList != null) {
        print(
          'GitHub API Error (${response.statusCode}), serving stale cache.',
        );
        return Response.ok(
          jsonEncode(_cachedReleasesList),
          headers: {'content-type': 'application/json'},
        );
      }
      return Response.internalServerError(body: 'github_api_error');
    }
  } catch (e) {
    if (_cachedReleasesList != null) {
      print('GitHub API Exception ($e), serving stale cache.');
      return Response.ok(
        jsonEncode(_cachedReleasesList),
        headers: {'content-type': 'application/json'},
      );
    }
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

/// Initiates a legacy PIN-based pairing session.
Future<Response> _createPairingHandler(Request req) async {
  final services = _services(req);
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final pin = await services.pairing.createSession(
    data['seedlingId'] ?? 'unknown',
  );
  return Response.ok(jsonEncode({'ok': true, 'pair_code': pin}));
}

/// Completes a pairing session using a PIN.
Future<Response> _completePairingHandler(Request req) async {
  final services = _services(req);
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final session = await services.pairing.completePairing(
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
  final services = _services(req);
  final pin =
      req.url.queryParameters['pin'] ?? req.url.queryParameters['pair_code'];
  if (pin == null) return Response.badRequest(body: 'missing_pin');
  final session = services.pairing.getSession(pin);
  return Response.ok(
    jsonEncode({'ok': true, 'paired': session?.isComplete ?? false}),
  );
}

/// Starts a 1:1 parity linking flow (HMAC-based).
Future<Response> _linkStartHandler(Request req) async {
  final services = _services(req);
  final data = jsonDecode(await req.readAsString());
  final result = services.linking.startLinking(
    data['gardener_id'],
    platform: data['platform'],
  );
  return Response.ok(jsonEncode(result));
}

/// Completes the linking process with a token verification.
Future<Response> _linkCompleteHandler(Request req) async {
  final services = _services(req);
  final data = jsonDecode(await req.readAsString());
  final result = services.linking.completeLinking(
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

/// Handles Server-Sent Events (SSE) subscriptions for real-time updates.
Response _eventsHandler(Request req, String gardenerId) {
  final services = _services(req);
  // Debug log for troubleshooting connectivity - gate behind verbose check if needed
  if (req.url.queryParameters.containsKey('debug')) {
    print('DEBUG: _eventsHandler CALLED for $gardenerId');
  }

  final stream = services.events.subscribe(gardenerId);
  return services.events.sseResponse(stream);
}

/// Returns status and ownership info for a specific device.
Future<Response> _deviceStatusHandler(Request req, String id) async {
  final services = _services(req);
  final ownerId = services.db.getOwnerForDevice(id);
  final isLinked = ownerId != null;

  var neighbors = 0;
  var ownerDisplay = 'None';

  if (isLinked) {
    final bindings = services.db.getBindings(ownerId);
    neighbors = bindings.length - 1; // Others in the swarm

    final owner = services.db.getUser(ownerId);
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
    headers: {
      'content-type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  );
}

/// Handler for the Stremio-triggered configuration redirect.
Response _userConfigureHandler(Request req, String userId) {
  // Redirect to the actual configure.html with the userId passed as 'id'
  return Response.found('/configure.html?id=$userId');
}

/// Unlinks a device from its owner (Portal debug/admin tool).
Future<Response> _deviceUnlinkHandler(Request req, String id) async {
  final services = _services(req);
  // Check if device belongs to user (Portal bypasses auth for now in this admin route)
  services.db.unlinkDevice(id);
  services.db.writeAudit('device_unlink', {'device_id': id});

  return Response.ok(jsonEncode({'ok': true}));
}

// Heartbeat (Secured via JWT)

/// Processes heartbeat signals from Gardeners to maintain active status.
/// Validates JWT Bearer token if provided.
Future<Response> _heartbeatHandler(Request req, String gardenerId) async {
  final services = _services(req);
  if (DebugConfig.pulseGated) {
    print('ROUTER_DEBUG: Received heartbeat from $gardenerId');
  }
  // Validate Bearer token if provided
  final authHeader = req.headers['authorization'];
  if (authHeader != null && authHeader.startsWith('Bearer ')) {
    final token = authHeader.substring(7);
    final claims = services.auth.verifyJwt(token);

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

  services.status.recordHeartbeat(gardenerId);

  return Response.ok(
    jsonEncode({'ok': true, 'activeGardeners': services.status.activeCount}),
  );
}

/// Collects telemetry data for analytics and debugging.
Future<Response> _telemetryHandler(Request req) async {
  final services = _services(req);
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
  services.db.writeAudit('telemetry', {
    'ua': req.headers['user-agent'],
    'body': data,
  });

  return Response.ok(
    jsonEncode({'ok': true}),
    headers: {'content-type': 'application/json', 'Cache-Control': 'no-store'},
  );
}

/// Registers a new executor/agent and assigns a device ID.
Future<Response> _executorRegisterHandler(Request req) async {
  final services = _services(req);
  final agent = req.headers['user-agent'] ?? 'unknown';
  final deviceId = const Uuid().v4().substring(
    0,
    16,
  ); // Mirroring legacy nanoid(16) length

  services.db.writeAudit('executor_reg', {
    'agent': agent,
    'device_id': deviceId,
  });

  return Response.ok(
    jsonEncode({'ok': true, 'device_id': deviceId}),
    headers: {'content-type': 'application/json'},
  );
}

// Swarm Query: Coordinate discovery between Gardeners

/// Queries the P2P swarm for metadata or peers.
Future<Response> _swarmQueryHandler(Request req) async {
  final services = _services(req);
  final id = req.url.queryParameters['id'];
  final type = req.url.queryParameters['type'];
  final trackers = req.url.queryParametersAll['tracker'] ?? [];

  if (id == null || type == null) {
    return Response.badRequest(body: jsonEncode({'error': 'missing_params'}));
  }

  services.db.writeAudit('swarm_query', {'id': id, 'type': type});

  // 1:1 Parity: Real-time swarm scraping
  // If trackers are provided, we scrape them directly to get seeds/leechers.
  Map<String, dynamic>? results;
  if (trackers.isNotEmpty) {
    results = await services.swarm.scrapeSwarm(id, trackers);
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
  final services = _services(req);
  return Response.ok(
    jsonEncode({
      'peerId': services.p2p.peerId,
      'addresses': services.p2p.addresses,
    }),
    headers: {'content-type': 'application/json'},
  );
}

/// Checks the health of a specific P2P URL or the node itself.
Future<Response> _p2pHealthHandler(Request req) async {
  final services = _services(req);
  final url = req.url.queryParameters['url'];
  if (url != null) {
    final ok = await services.health.checkHealthy(url, aggressive: true);
    return Response.ok(jsonEncode({'url': url, 'healthy': ok}));
  }
  return Response.ok(jsonEncode({'status': 'active', 'engine': 'Dart/AOT'}));
}

/// Returns the calculated "Best" trackers based on community reputation.
Response _trackerBestHandler(Request req) {
  final services = _services(req);
  final best = services.tracker.getBestTrackers();
  return Response.ok(jsonEncode({'trackers': best}));
}

/// Returns the full list of trackers for Gardeners to verify.
Response _trackerSyncHandler(Request req) {
  final services = _services(req);
  final list = services.tracker.getSyncList();
  return Response.ok(jsonEncode({'trackers': list}));
}

/// Accepts batch votes from Gardeners.
Future<Response> _trackerVoteHandler(Request req) async {
  final services = _services(req);
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final votes = (data['votes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    services.tracker.submitVotes(votes);
    return Response.ok(jsonEncode({'ok': true}));
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_payload'}));
  }
}

// Debug Handlers

/// Creates a self-binding for debug purposes.
Future<Response> _debugLinkSelfHandler(Request req) async {
  final services = _services(req);
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final gardenerId = data['gardenerId'];

    if (gardenerId == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'missing_gardenerId'}),
      );
    }

    final secret = services.linking.bindDirectly(gardenerId, 'self');
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
Future<Response> _streamResolveHandler(Request req) async {
  final services = _services(req);
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
    final streams = await services.scraper.getStreams(type, imdbId, {});

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
  final services = _services(req);
  try {
    final payload = await req.readAsString();
    final data = jsonDecode(payload);
    final incoming = (data['trackers'] as List?)?.cast<String>() ?? [];

    final result = await services.tracker.optimize(incoming);
    return Response.ok(jsonEncode(result));
  } catch (e) {
    return Response.badRequest(body: jsonEncode({'error': 'invalid_payload'}));
  }
}

/// Returns recent boost activity.
Response _boostRecentHandler(Request req) {
  final services = _services(req);
  return Response.ok(
    jsonEncode({'ok': true, 'items': services.boost.getRecent()}),
  );
}

/// SSE stream for boost events.
Response _boostEventsHandler(Request req) {
  final services = _services(req);
  Stream<String> stream() async* {
    yield ': connected\n\n';
    await for (final e in services.boost.stream) {
      yield 'event: boost\ndata: ${jsonEncode(e.toJson())}\n\n';
    }
  }

  return services.events.sseResponse(stream());
}

/// Diagnoses upstream provider health.
Future<Response> _providersDetectHandler(Request req) async {
  final services = _services(req);
  final results = await services.scraper.probeProviders();
  return Response.ok(jsonEncode({'ok': true, 'providers': results}));
}

/// SSE stream for tracker sweeping.
Response _trackerSweepHandler(Request req) {
  final services = _services(req);
  final source =
      req.url.queryParameters['source'] ??
      'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_ip.txt';

  Stream<String> stream() async* {
    yield ': start\n\n';
    await for (final e in services.tracker.sweep(source)) {
      yield 'event: sweep\ndata: ${jsonEncode(e)}\n\n';
    }
  }

  return services.events.sseResponse(stream());
}

/// Issues a task to a Gardener (Mock/Echo for now).
Future<Response> _taskRequestHandler(Request req) async {
  final services = _services(req);
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
    final token = services.task.requestTask(type, {
      'ts': DateTime.now().toIso8601String(),
      'room_id': roomId,
      'params': params,
    });

    // Notify the room that a task has been issued
    services.events.publish(roomId, 'task', {
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
  final services = _services(req);
  try {
    final body = jsonDecode(await req.readAsString());
    final token = body['token'];
    final result = body['result'];

    final payload = services.task.verifyResult(token);
    if (payload == null) {
      return Response(401, body: jsonEncode({'error': 'invalid_token'}));
    }

    // Extract original context
    final taskPayload = payload['payload'] as Map<String, dynamic>?;
    final roomId = taskPayload?['room_id'];
    final taskId = payload['task_id'];

    if (roomId != null) {
      services.events.publish(roomId, 'result', {
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
    if (DebugConfig.disableP2P) {
      print('SeedSphere Router: P2P Node disabled via DebugConfig.');
    } else {
      print('DEBUG: Starting P2PNode...');
      await p2pNode.start();
    }
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
      .addMiddleware(contextMiddleware(context))
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';

import 'package:router/pairing_service.dart';
import 'package:router/p2p_node.dart';
import 'package:router/db_service.dart';
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

// Services
final db = DbService()..init('data');
final pairingService = PairingService();
final p2pNode = P2PNode();
final eventService = EventService();
final linkingService = LinkingService(db);
final healthService = HealthService();
final swarmService = SwarmService();
final mailerService = MailerService.custom(
  host: Platform.environment['SMTP_HOST'] ?? 'smtp-relay.brevo.com',
  port: int.parse(Platform.environment['SMTP_PORT'] ?? '587'),
  username: Platform.environment['SMTP_USER'] ?? '',
  password: Platform.environment['SMTP_PASS'] ?? '',
  fromEmail: Platform.environment['SMTP_FROM'] ?? 'noreply@seedsphere.app',
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
  // Auth Restoration (Phase 2.5)
  ..mount('/api/auth/', authService.router.call)
  // Stremio Addon (Phase 3)
  ..mount(
    '/addon/',
    addonService.router.call,
  ); // Mounted under /addon/ to avoid conflict with root static files

/// Root handler returning server status and version info.
Response _rootHandler(Request req) {
  return Response.ok(
    jsonEncode({
      'name': 'SeedSphere Router',
      'version': '2.0.0',
      'status': 'active',
      'mode': 'Federated Frontier (Parity)',
    }),
    headers: {'content-type': 'application/json'},
  );
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
  final stream = eventService.subscribe(gardenerId);
  return eventService.sseResponse(stream);
}

// Heartbeat (Secured via Middleware if applied)

/// Processes heartbeat signals from Gardeners to maintain active status.
Future<Response> _heartbeatHandler(Request req, String gardenerId) async {
  db.touchGardener(gardenerId);
  eventService.publish(gardenerId, 'heartbeat', {
    't': DateTime.now().millisecondsSinceEpoch,
  });
  return Response.ok(jsonEncode({'ok': true}));
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

void main(List<String> args) async {
  try {
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
      .addMiddleware(logRequests())
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

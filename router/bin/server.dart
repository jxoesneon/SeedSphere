import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:router/pairing_service.dart';
import 'package:router/p2p_node.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/linking_service.dart';
import 'package:router/security_middleware.dart';
import 'package:router/rate_limit_middleware.dart';
import 'package:router/health_service.dart';
import 'package:router/swarm_service.dart';
import 'package:uuid/uuid.dart';

// Services
final db = DbService()..init('data');
final pairingService = PairingService();
final p2pNode = P2PNode();
final eventService = EventService();
final linkingService = LinkingService(db);
final healthService = HealthService();
final swarmService = SwarmService();

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
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
  ..get('/p2p/health', _p2pHealthHandler);

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

Response _healthHandler(Request req) {
  return Response.ok(
    jsonEncode({'status': 'healthy'}),
    headers: {'content-type': 'application/json'},
  );
}

// PIN Pairing (Legacy)
Future<Response> _createPairingHandler(Request req) async {
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final pin = await pairingService.createSession(
    data['seedlingId'] ?? 'unknown',
  );
  return Response.ok(jsonEncode({'ok': true, 'pair_code': pin}));
}

Future<Response> _completePairingHandler(Request req) async {
  final payload = await req.readAsString();
  final data = jsonDecode(payload);
  final session = await pairingService.completePairing(
    data['pin'] ?? data['pair_code'],
    data['gardenerId'] ?? data['device_id'],
  );
  if (session == null)
    return Response.notFound(jsonEncode({'ok': false, 'error': 'not_found'}));
  return Response.ok(jsonEncode({'ok': true, ...session.toJson()}));
}

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
Future<Response> _linkStartHandler(Request req) async {
  final data = jsonDecode(await req.readAsString());
  final result = linkingService.startLinking(
    data['gardener_id'],
    platform: data['platform'],
  );
  return Response.ok(jsonEncode(result));
}

Future<Response> _linkCompleteHandler(Request req) async {
  final data = jsonDecode(await req.readAsString());
  final result = linkingService.completeLinking(
    data['token'],
    data['seedling_id'],
  );
  if (result == null)
    return Response.notFound(jsonEncode({'ok': false, 'error': 'expired'}));
  return Response.ok(jsonEncode(result));
}

Response _linkStatusHandler(Request req) {
  final gId = req.url.queryParameters['gardener_id'];
  // Simplified status for 1:1 parity demonstration
  return Response.ok(jsonEncode({'ok': true, 'linked': gId != null}));
}

// Events (SSE)
Response _eventsHandler(Request req, String gardenerId) {
  final stream = eventService.subscribe(gardenerId);
  return eventService.sseResponse(stream);
}

// Heartbeat (Secured via Middleware if applied)
Future<Response> _heartbeatHandler(Request req, String gardenerId) async {
  db.touchGardener(gardenerId);
  eventService.publish(gardenerId, 'heartbeat', {
    't': DateTime.now().millisecondsSinceEpoch,
  });
  return Response.ok(jsonEncode({'ok': true}));
}

// Telemetry Collector
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

Response _p2pInfoHandler(Request req) {
  return Response.ok(
    jsonEncode({'peerId': p2pNode.peerId, 'addresses': p2pNode.addresses}),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _p2pHealthHandler(Request req) async {
  final url = req.url.queryParameters['url'];
  if (url != null) {
    final ok = await healthService.checkHealthy(url, aggressive: true);
    return Response.ok(jsonEncode({'url': url, 'healthy': ok}));
  }
  return Response.ok(jsonEncode({'status': 'active', 'engine': 'Dart/AOT'}));
}

/// Middleware for security hardening headers (CSP, HSTS, etc.)
Middleware securityHardeningMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);

      // 1:1 Parity: Audit CORS and access
      try {
        db.writeAudit('access', {
          'ip':
              request.context['shelf.io.connection_info']?.remoteAddress ??
              'unknown',
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
              "default-src 'self'; script-src 'self'; object-src 'none';",
          ...response.headers, // Keep existing headers
        },
      );
    };
  };
}

void main(List<String> args) async {
  await p2pNode.start();

  // Periodic Cleanup (Parity)
  Timer.periodic(const Duration(minutes: 15), (timer) {
    print('SeedSphere Router: Pruning expired data...');
    db.pruneExpiredData();
  });

  final securePipeline = Pipeline().addMiddleware(
    securityMiddleware((g, s) async => db.getBindingSecret(g, s)),
  );

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(securityHardeningMiddleware())
      .addMiddleware(rateLimitMiddleware()) // Global rate limiting
      .addHandler((Request request) {
        // Apply security middleware ONLY to the heartbeat endpoint for parity compliance
        if (request.url.path.contains('heartbeat')) {
          return securePipeline.addHandler(_router.call)(request);
        }
        return _router.call(request);
      });

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print(
    'SeedSphere Router (1:1 Parity Polish) listening on port ${server.port}',
  );
}

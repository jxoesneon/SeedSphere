import 'dart:convert';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:router/controllers/device_controller.dart';
import 'package:router/controllers/telemetry_controller.dart';
import 'package:mockito/mockito.dart';
import 'package:router/db_service.dart';
import 'package:router/core/server_context.dart';
import 'package:router/auth_service.dart';
import 'package:router/event_service.dart';
import 'package:router/health_service.dart';
import 'package:router/linking_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/pairing_service.dart';
import 'package:router/p2p_node.dart';
import 'package:router/prefetch_service.dart';
import 'package:router/swarm_service.dart';
import 'package:router/task_service.dart';
import 'package:router/tracker_service.dart';
import 'package:router/boost_service.dart';
import 'package:router/addon_service.dart';
import 'package:router/services/distributed_scraper_service.dart';
import 'package:router/services/status_service.dart';

// Mock Services
class MockDbService extends Mock implements DbService {}

class MockAuthService extends Mock implements AuthService {}

// Stubbed ServerContext
class StubServerContext extends ServerContext {
  StubServerContext({
    required super.db,
    required super.auth,
    required super.pairing,
    required super.p2p,
    required super.events,
    required super.linking,
    required super.health,
    required super.swarm,
    required super.mailer,
    required super.tracker,
    required super.scraper,
    required super.addon,
    required super.boost,
    required super.prefetch,
    required super.task,
    required super.status,
  });
}

class MockPairingService extends Mock implements PairingService {}

class MockP2PNode extends Mock implements P2PNode {}

class MockEventService extends Mock implements EventService {}

class MockLinkingService extends Mock implements LinkingService {}

class MockHealthService extends Mock implements HealthService {}

class MockSwarmService extends Mock implements SwarmService {}

class MockMailerService extends Mock implements MailerService {}

class MockTrackerService extends Mock implements TrackerService {}

class MockScraperService extends Mock implements DistributedScraperService {}

class MockAddonService extends Mock implements AddonService {}

class MockBoostService extends Mock implements BoostService {}

class MockPrefetchService extends Mock implements PrefetchService {}

class MockTaskService extends Mock implements TaskService {}

class MockStatusService extends Mock implements StatusService {}

void main() {
  group('DeviceController', () {
    late DeviceController controller;
    late MockDbService mockDb;
    late MockAuthService mockAuth;
    late ServerContext context;

    setUp(() {
      mockDb = MockDbService();
      mockAuth = MockAuthService();

      context = StubServerContext(
        db: mockDb,
        auth: mockAuth,
        pairing: MockPairingService(),
        p2p: MockP2PNode(),
        events: MockEventService(),
        linking: MockLinkingService(),
        health: MockHealthService(),
        swarm: MockSwarmService(),
        mailer: MockMailerService(),
        tracker: MockTrackerService(),
        scraper: MockScraperService(),
        addon: MockAddonService(),
        boost: MockBoostService(),
        prefetch: MockPrefetchService(),
        task: MockTaskService(),
        status: MockStatusService(),
      );

      controller = DeviceController(mockDb);
    });

    test('unlink returns 401 if no auth header', () async {
      final req = Request('POST', Uri.parse('http://localhost/unlink/123'));
      final response = await controller.unlink(req, '123', context);
      expect(response.statusCode, 401);
    });
  });

  group('TelemetryController', () {
    late TelemetryController controller;
    late MockDbService mockDb;

    setUp(() {
      mockDb = MockDbService();
      controller = TelemetryController(mockDb);
    });

    test('handle returns 403 if key is missing', () async {
      final req = Request(
        'POST',
        Uri.parse('http://localhost/api/telemetry'),
        body: jsonEncode({'some': 'data'}),
      );
      final response = await controller.handle(req);
      expect(response.statusCode, 403);
    });
  });
}

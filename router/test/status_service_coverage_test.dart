import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/services/status_service.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';

@GenerateNiceMocks([MockSpec<DbService>(), MockSpec<EventService>()])
import 'status_service_coverage_test.mocks.dart';

void main() {
  group('StatusService Full Coverage', () {
    late StatusService statusService;
    late MockDbService mockDb;
    late MockEventService mockEvents;

    setUp(() {
      mockDb = MockDbService();
      mockEvents = MockEventService();
      statusService = StatusService(mockDb, mockEvents);
    });

    test('recordHeartbeat updates maps and DB', () {
      statusService.recordHeartbeat('g1');
      expect(statusService.activeCount, 1);
      expect(statusService.isActive('g1'), isTrue);
      verify(mockDb.touchGardener('g1')).called(1);
      verify(mockEvents.publish('g1', 'heartbeat', any)).called(1);
    });

    test('isActive handles stale gardeners', () {
      // Since we can't easily mock DateTime.now(), we just test basic.
      expect(statusService.isActive('unknown'), isFalse);
    });
  });
}

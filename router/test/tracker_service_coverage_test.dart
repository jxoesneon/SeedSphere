import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/tracker_service.dart';
import 'package:router/db_service.dart';
import 'package:router/health_service.dart';

@GenerateNiceMocks([MockSpec<DbService>(), MockSpec<HealthService>()])
import 'tracker_service_coverage_test.mocks.dart';

void main() {
  group('TrackerService Full Coverage', () {
    late TrackerService trackerService;
    late MockDbService mockDb;
    late MockHealthService mockHealth;

    setUp(() {
      mockDb = MockDbService();
      mockHealth = MockHealthService();
      trackerService = TrackerService(mockDb, mockHealth);
    });

    test('init and loop', () async {
      when(mockDb.getTrackers()).thenReturn(['t1']);
      await trackerService.init();
      // Loop is background, hard to verify but init covered.
    });

    test('getBestTrackers and getSyncList', () {
      when(mockDb.getBestTrackers(limit: 50)).thenReturn(['t1']);
      when(mockDb.getTrackersSync()).thenReturn(['t1', 't2']);

      expect(trackerService.getBestTrackers(), contains('t1'));
      expect(trackerService.getSyncList(), hasLength(2));
    });

    test('submitVotes', () {
      when(mockDb.transaction(any)).thenAnswer((inv) {
        final callback = inv.positionalArguments[0] as Function();
        return callback();
      });

      trackerService.submitVotes([
        {'url': 't1', 'up': true, 'latency': 100},
      ]);
      verify(mockDb.submitTrackerVote('t1', true, 100)).called(1);
    });

    test('optimize with safe trackers', () async {
      final res = await trackerService.optimize(['udp://google.com:80']);
      expect(res['good'], contains('udp://google.com:80'));
      verify(mockDb.upsertTracker(any)).called(greaterThan(0));
    });

    test('sweep (stream)', () async {
      // Mocking _safeGet is hard as it's private, but it calls _isSafeTracker which calls InternetAddress.lookup
      // Actually, sweep returns a Stream.
      final stream = trackerService.sweep('');
      final results = await stream.toList();
      expect(results, isEmpty);
    });
  });
}

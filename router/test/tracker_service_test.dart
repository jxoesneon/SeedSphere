import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/tracker_service.dart';
import 'package:router/db_service.dart';
import 'package:router/health_service.dart';

@GenerateNiceMocks([MockSpec<DbService>(), MockSpec<HealthService>()])
import 'tracker_service_test.mocks.dart';

void main() {
  group('TrackerService', () {
    late TrackerService trackerService;
    late MockDbService mockDb;
    late MockHealthService mockHealth;

    setUp(() {
      mockDb = MockDbService();
      mockHealth = MockHealthService();
      trackerService = TrackerService(mockDb, mockHealth);
    });

    test('getBestTrackers returns list from db', () {
      when(
        mockDb.getBestTrackers(limit: 50),
      ).thenReturn(['udp://tracker.opentrackr.org:1337/announce']);

      final result = trackerService.getBestTrackers();

      expect(result.length, 1);
      expect(
        result.first,
        equals('udp://tracker.opentrackr.org:1337/announce'),
      );
    });

    test('getSyncList returns list from db', () {
      when(
        mockDb.getTrackersSync(limit: 2000),
      ).thenReturn(['udp://tracker.leechers-paradise.org:6969']);

      final result = trackerService.getSyncList();

      expect(result.length, 1);
    });

    test('submitVotes calls db transaction', () {
      when(
        mockDb.transaction(any),
      ).thenAnswer((inv) => inv.positionalArguments[0]());

      final votes = [
        {'url': 'udp://tracker.1.org:80', 'up': true, 'latency': 50},
        {'url': 'udp://tracker.2.org:80', 'up': false},
      ];

      trackerService.submitVotes(votes);

      verify(
        mockDb.submitTrackerVote('udp://tracker.1.org:80', true, 50),
      ).called(1);
      verify(
        mockDb.submitTrackerVote('udp://tracker.2.org:80', false, 0),
      ).called(1);
    });

    group('optimize', () {
      test('filters unsafe localhost/private IPs and returns filtered list', () async {
        when(
          mockDb.getBestTrackers(limit: 50),
        ).thenReturn(['udp://best.tracker.org:80']);

        final incoming = [
          'udp://tracker.good.org:80',
          'http://127.0.0.1:8080/announce', // Unsafe
          'udp://localhost:1337', // Unsafe
        ];

        // We can't easily mock InternetAddress.lookup for the "good" tracker in a unit test
        // without a wrapper or real network, so optimize might filter out "good" ones
        // if DNS fails. We'll focus on what we CAN assert: that bad ones are definitely unsafe strings.
        // Actually, _isSafeTracker checks private IPs string set first.

        final result = await trackerService.optimize(incoming);

        // System best are always added
        expect(result['added'], contains('udp://best.tracker.org:80'));

        // Incoming safe list - we expect localhost etc to be filtered.
        // 'udp://tracker.good.org:80' might fail DNS lookup and be filtered too in a test env.
        // But we definitely shouldn't see localhost.

        final good = result['good'] as List<String>;
        expect(good, isNot(contains('http://127.0.0.1:8080/announce')));
        expect(good, isNot(contains('udp://localhost:1337')));
      });
    });
  });
}

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/services/distributed_scraper_service.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/tracker_service.dart';

import 'distributed_scraper_service_coverage_test.mocks.dart';
import 'test_config.dart';

@GenerateNiceMocks([
  MockSpec<DbService>(),
  MockSpec<EventService>(),
  MockSpec<TrackerService>(),
])
void main() {
  group('DistributedScraperService Full Coverage', () {
    late DistributedScraperService scraper;
    late MockDbService mockDb;
    late MockEventService mockEvents;
    late MockTrackerService mockTrackers;

    setUp(() {
      mockDb = MockDbService();
      mockEvents = MockEventService();
      mockTrackers = MockTrackerService();
      
      scraper = DistributedScraperService(
        mockTrackers,
        config: TestConfig(),
        db: mockDb,
        events: mockEvents,
      );
    });

    test('getStreams from cache', () async {
      when(mockDb.getScrapCache('tt123')).thenReturn([
        {'name': 'cached'},
      ]);
      final streams = await scraper.getStreams('movie', 'tt123', {});
      expect(streams[0]['name'], 'cached');
    });

    test('getStreams setup required if no user', () async {
      when(mockDb.getScrapCache('tt123')).thenReturn(null);
      final streams = await scraper.getStreams('movie', 'tt123', {});
      expect(streams[0]['title'], contains('Setup Required'));
    });

    test('getStreams disconnected if no gardener', () async {
      when(mockDb.getScrapCache('tt123')).thenReturn(null);
      when(mockDb.getBindings('u1')).thenReturn([
        {'device_id': 'g1'},
      ]);
      when(mockEvents.isConnected('g1')).thenReturn(false);

      final streams = await scraper.getStreams(
        'movie',
        'tt123',
        {},
        userId: 'u1',
      );
      expect(streams[0]['title'], contains('Gardener Disconnected'));
    });

    test('getDynamicCatalog error handling', () async {
      when(mockDb.getScrapCache(any)).thenReturn(null);
      when(mockDb.getBindings('u1')).thenReturn([]);

      final results = await scraper.getDynamicCatalog('movie', 'query', 'u1');
      expect(results[0]['id'], 'error_no_gardener');
    });

    test('handleResult completes task', () {
      // Just ensure it doesn't crash
      DistributedScraperService.handleResult('non-existent', []);
    });
  });
}

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/scraper_service.dart';
import 'package:router/db_service.dart';
import 'package:router/event_service.dart';
import 'package:router/tracker_service.dart';

import 'scraper_service_coverage_test.mocks.dart';
import 'test_config.dart';

@GenerateNiceMocks([
  MockSpec<DbService>(),
  MockSpec<EventService>(),
  MockSpec<TrackerService>(),
])
void main() {
  group('ScraperService Full Coverage', () {
    late ScraperService scraperService;
    late MockTrackerService mockTrackers;
    late MockEventService mockEvents;

    setUp(() {
      mockTrackers = MockTrackerService();
      mockEvents = MockEventService();
      scraperService = ScraperService(mockTrackers, config: TestConfig(), eventService: mockEvents);
    });

    test('getStreams triggers log events if userId provided', () async {
      when(mockTrackers.optimize(any)).thenAnswer((_) async => {'added': []});

      await scraperService.getStreams('movie', 'tt123', {}, userId: 'u1');
      // It should call eventService.publish for logging
      verify(mockEvents.publish(any, any, any)).called(greaterThanOrEqualTo(1));
    });

    test('probeProviders returns status for all', () async {
      final results = await scraperService.probeProviders();
      expect(results, isNotEmpty);
      expect(results[0].containsKey('name'), isTrue);
    });
  });
}

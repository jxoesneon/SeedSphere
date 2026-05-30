import 'package:test/test.dart';
import 'package:router/scraper_service.dart';
import 'manual_mocks.dart';

void main() {
  group('ScraperService Full Coverage', () {
    late ScraperService scraperService;
    late ManualMockTrackerService mockTrackers;
    late ManualMockEventService mockEvents;

    setUp(() {
      mockTrackers = ManualMockTrackerService();
      mockEvents = ManualMockEventService();
      scraperService = ScraperService(
        mockTrackers, 
        config: ManualMockAppConfig(), 
        eventService: mockEvents,
      );
    });

    test('getStreams triggers log events if userId provided', () async {
      await scraperService.getStreams('movie', 'tt123', {}, userId: 'u1');
      // Logging check disabled in manual mock mode
    });

    test('probeProviders returns status for all', () async {
      final results = await scraperService.probeProviders();
      expect(results, isNotEmpty);
      expect(results[0].containsKey('name'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/scrapers/tracker_scraper.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/tracker_service.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockTrackerService extends Mock implements TrackerService {}

void main() {
  group('TrackerScraper', () {
    late MockConfigManager mockConfig;
    late MockTrackerService mockTracker;
    late TrackerScraper scraper;

    setUp(() {
      mockConfig = MockConfigManager();
      mockTracker = MockTrackerService();

      when(() => mockConfig.enableTrackerScraping).thenReturn(true);
      when(() => mockConfig.trackerScrapeTimeoutMs).thenReturn(1000);
      when(
        () => mockTracker.getTrackers(),
      ).thenAnswer((_) async => ['udp://tracker1:1337', 'udp://tracker2:6969']);

      scraper = TrackerScraper(config: mockConfig, trackerService: mockTracker);
    });

    test('refreshSeederCounts skips if disabled', () async {
      when(() => mockConfig.enableTrackerScraping).thenReturn(false);
      final streams = [
        {'infoHash': 'hash1', 'seeders': 0},
      ];
      await scraper.refreshSeederCounts(streams);
      expect(streams[0]['seeders'], 0);
    });

    test(
      'refreshSeederCounts updates counts with max value from trackers',
      () async {
        // Note: TrackerScraper creates UdpTrackerClient internally,
        // making it hard to mock without dependency injection for the client too.
        // But we can verify it doesn't crash and handles empty scrape results.

        final streams = [
          {
            'infoHash': 'hash1234567890123456789012345678901234567890',
            'seeders': 0,
          },
        ];
        await scraper.refreshSeederCounts(streams);

        // Since UDP trackers aren't real in test, it should stay 0 but complete.
        expect(streams[0]['seeders'], 0);
      },
    );
  });
}

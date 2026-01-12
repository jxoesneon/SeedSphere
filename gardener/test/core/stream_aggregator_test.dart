import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/stream_aggregator.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/tracker_service.dart';
import 'package:gardener/core/cortex_service.dart';
import 'package:mocktail/mocktail.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockTrackerService extends Mock implements TrackerService {}

class MockCortexService extends Mock implements CortexService {}

void main() {
  group('StreamAggregator', () {
    late MockConfigManager mockConfig;
    late MockTrackerService mockTrackerService;
    late MockCortexService mockCortexService;

    setUp(() async {
      mockConfig = MockConfigManager();
      mockTrackerService = MockTrackerService();
      mockCortexService = MockCortexService();

      // ConfigManager mocks - all properties used by StreamAggregator
      when(() => mockConfig.autoProxy).thenReturn(true);
      when(() => mockConfig.maxTrackers).thenReturn(10);
      when(() => mockConfig.sortBy).thenReturn('Resolution');
      when(() => mockConfig.excludeCam).thenReturn(false);
      when(() => mockConfig.exclude3D).thenReturn(false);
      when(() => mockConfig.includeRegex).thenReturn('');
      when(() => mockConfig.excludeRegex).thenReturn('');
      when(() => mockConfig.neuroLinkEnabled).thenReturn(false);
      when(() => mockConfig.requireDetailsForOriginal).thenReturn(false);
      when(() => mockConfig.appendOriginalDesc).thenReturn(false);

      // Missing stubs added to fix null safety errors
      when(() => mockConfig.preferEncrypted).thenReturn(false);
      when(() => mockConfig.maxResolution).thenReturn('4k');
      when(() => mockConfig.prioritizedLanguages).thenReturn([]);
      when(() => mockConfig.preferHDR).thenReturn(false);
      when(() => mockConfig.seriesTitleCleanup).thenReturn(true);
      when(() => mockConfig.preferredSourceType).thenReturn('Any');
      when(() => mockConfig.enableTrackerScraping).thenReturn(true);
      when(() => mockConfig.trackerScrapeTimeoutMs).thenReturn(1000);
      when(() => mockConfig.maxResultsPerProvider).thenReturn(15);

      // TrackerService mock - return test trackers
      when(() => mockTrackerService.getTrackers()).thenAnswer(
        (_) async => [
          'udp://tracker.opentrackr.org:1337/announce',
          'udp://tracker.openbittorrent.com:6969/announce',
        ],
      );
    });

    test('aggregateStreams dedupes, sorts, and enriches', () async {
      final aggregator = StreamAggregator(
        config: mockConfig,
        trackerService: mockTrackerService,
        cortex: mockCortexService,
      );

      final rawResults = [
        // 1. 1080p stream with low seeds, but correct hash
        {
          'title': 'Test Movie 1080p',
          'infoHash': 'aabbccddeeff00112233445566778899aabbccdd',
          'seeders': 10,
          'leechers': 5,
        },
        // 2. Same hash as above, but better seeds (should merge)
        {
          'title': 'Test Movie [1080p] Repack',
          'infoHash': 'aabbccddeeff00112233445566778899aabbccdd',
          'seeders': 50,
          'leechers': 10,
        },
        // 3. 4K stream (should be ranked first)
        {
          'title': 'Test Movie 4K HDR',
          'infoHash': '00112233445566778899aabbccddeeff00112233',
          'seeders': 5,
          'leechers': 1,
        },
        // 4. Garbage/Invalid
        {'title': 'Bad Data', 'infoHash': ''},
      ];

      final streams = await aggregator.aggregateStreams(rawResults);

      expect(streams.length, 2); // 4K + 1080p (merged)

      // Check Sorting: 4K First (4K Rank=40 > 1080p Rank=30)
      expect(streams[0]['behaviorHints']['bingeGroup'], contains('2160P'));
      expect(streams[0]['title'], 'Test Movie 4K HDR');

      // Check Dedupe/Merge of 1080p
      expect(streams[1]['behaviorHints']['bingeGroup'], contains('1080P'));
      expect(streams[1]['seeders'], 50); // Took the higher seed count

      // Check Description
      final desc = streams[0]['description'] as String;
      expect(desc, contains('💿 2160P'));
      expect(desc, contains('HDR')); // From title parsing

      // Check Tracker Injection
      final mag1 = streams[0]['magnet'] as String;
      expect(
        mag1,
        contains('xt=urn:btih:00112233445566778899aabbccddeeff00112233'),
      );
      // Should have appended trackers
      expect(mag1, contains('tr='));
    });
    test('aggregateStreams applies language priority boost', () async {
      when(() => mockConfig.prioritizedLanguages).thenReturn(['Spanish']);

      final aggregator = StreamAggregator(
        config: mockConfig,
        trackerService: mockTrackerService,
        cortex: mockCortexService,
      );

      final rawResults = [
        {'title': 'Movie English', 'infoHash': 'hash1', 'seeders': 100},
        {'title': 'Movie Spanish', 'infoHash': 'hash2', 'seeders': 10},
      ];

      final streams = await aggregator.aggregateStreams(rawResults);

      // Spanish should be first due to priority boost (+50000)
      expect(streams[0]['infoHash'], 'hash2');
      expect(streams[1]['infoHash'], 'hash1');
    });

    test('aggregateStreams applies HDR bonus', () async {
      when(() => mockConfig.preferHDR).thenReturn(true);

      final aggregator = StreamAggregator(
        config: mockConfig,
        trackerService: mockTrackerService,
        cortex: mockCortexService,
      );

      final rawResults = [
        {'title': 'Movie 1080p SDR', 'infoHash': 'hash1', 'seeders': 100},
        {'title': 'Movie 1080p HDR', 'infoHash': 'hash2', 'seeders': 100},
      ];

      final streams = await aggregator.aggregateStreams(rawResults);

      // HDR should be first
      expect(streams[0]['infoHash'], 'hash2');
    });
  });
}

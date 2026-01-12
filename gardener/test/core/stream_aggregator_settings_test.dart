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
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConfigManager mockConfig;
  late MockTrackerService mockTrackerService;
  late MockCortexService mockCortex;
  late StreamAggregator aggregator;

  setUp(() {
    mockConfig = MockConfigManager();
    mockTrackerService = MockTrackerService();
    mockCortex = MockCortexService();

    // All ConfigManager properties used by StreamAggregator
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
    when(() => mockConfig.preferEncrypted).thenReturn(false);
    when(() => mockConfig.maxResolution).thenReturn('4k');
    when(() => mockConfig.prioritizedLanguages).thenReturn([]);
    when(() => mockConfig.preferHDR).thenReturn(false);
    when(() => mockConfig.seriesTitleCleanup).thenReturn(true);
    when(() => mockConfig.preferredSourceType).thenReturn('torrent');

    // TrackerService mock
    when(() => mockTrackerService.getTrackers()).thenAnswer(
      (_) async => [
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://tracker.openbittorrent.com:6969/announce',
      ],
    );

    aggregator = StreamAggregator(
      config: mockConfig,
      trackerService: mockTrackerService,
      cortex: mockCortex,
    );
  });

  group('StreamAggregator Settings Integration', () {
    test('filters CAM content when excludeCam is true', () async {
      when(() => mockConfig.excludeCam).thenReturn(true);

      final raw = [
        {
          'title': 'Good Movie 1080p',
          'infoHash': 'hash1111111111111111111111111111111111111',
        },
        {
          'title': 'Garbage CAM 720p',
          'infoHash': 'hash2222222222222222222222222222222222222',
        },
      ];

      final results = await aggregator.aggregateStreams(raw);
      expect(results.length, 1);
      expect(results[0]['title'], contains('Good Movie'));
    });

    test('filters 3D content when exclude3D is true', () async {
      when(() => mockConfig.exclude3D).thenReturn(true);

      final raw = [
        {
          'title': 'Movie 4K',
          'infoHash': 'hash1111111111111111111111111111111111111',
        },
        {
          'title': 'Movie 3D SBS',
          'infoHash': 'hash2222222222222222222222222222222222222',
        },
      ];

      final results = await aggregator.aggregateStreams(raw);
      expect(results.length, 1);
      expect(results[0]['title'], 'Movie 4K');
    });

    test('applies custom regex include/exclude', () async {
      when(() => mockConfig.includeRegex).thenReturn('HDR');
      when(() => mockConfig.excludeRegex).thenReturn('x265');

      final raw = [
        {
          'title': 'Movie HDR x264',
          'infoHash': 'hash1111111111111111111111111111111111111',
        }, // Keep
        {
          'title': 'Movie HDR x265',
          'infoHash': 'hash2222222222222222222222222222222222222',
        }, // Exclude (x265)
        {
          'title': 'Movie SDR x264',
          'infoHash': 'hash3333333333333333333333333333333333333',
        }, // Exclude (no HDR)
      ];

      final results = await aggregator.aggregateStreams(raw);
      expect(results.length, 1);
      expect(results[0]['title'], contains('HDR x264'));
    });

    test('sorts by Seeders when configured', () async {
      when(() => mockConfig.sortBy).thenReturn('Seeders');

      final raw = [
        {
          'title': 'Movie 4K',
          'infoHash': 'hash1111111111111111111111111111111111111',
          'seeders': 10,
        },
        {
          'title': 'Movie 1080p',
          'infoHash': 'hash2222222222222222222222222222222222222',
          'seeders': 100,
        },
      ];

      final results = await aggregator.aggregateStreams(raw);
      // Even though 4K has higher res rank, Seeders should win if configured
      expect(results[0]['title'], contains('1080p'));
      expect(results[1]['title'], contains('4K'));
    });

    test(
      'enriches with AI description when neuroLinkEnabled is true',
      () async {
        when(() => mockConfig.neuroLinkEnabled).thenReturn(true);
        when(
          () => mockCortex.generateDescription(
            title: any(named: 'title'),
            type: any(named: 'type'),
            metadata: any(named: 'metadata'),
          ),
        ).thenAnswer(
          (_) async => 'This is a high quality AI generated summary.',
        );

        final raw = [
          {
            'title': 'The Matrix 4K',
            'infoHash': 'hash1111111111111111111111111111111111111',
            'seeders': 100,
          },
        ];

        final results = await aggregator.aggregateStreams(raw);
        expect(
          results[0]['description'],
          contains('🧠 This is a high quality AI generated summary.'),
        );
      },
    );
  });
}

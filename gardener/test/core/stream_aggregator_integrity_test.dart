import 'package:test/test.dart';
import 'package:gardener/core/stream_aggregator.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/tracker_service.dart';
import 'package:gardener/core/cortex_service.dart';
import 'package:mocktail/mocktail.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockTrackerService extends Mock implements TrackerService {}

class MockCortexService extends Mock implements CortexService {}

void main() {
  late StreamAggregator aggregator;
  late MockConfigManager mockConfig;
  late MockTrackerService mockTrackerService;
  late MockCortexService mockCortexService;

  setUp(() {
    mockConfig = MockConfigManager();
    mockTrackerService = MockTrackerService();
    mockCortexService = MockCortexService();

    when(() => mockConfig.autoProxy).thenReturn(true);
    when(() => mockConfig.maxTrackers).thenReturn(0);
    when(() => mockConfig.sortBy).thenReturn('Resolution');
    when(() => mockConfig.excludeCam).thenReturn(false);
    when(() => mockConfig.exclude3D).thenReturn(false);
    when(() => mockConfig.includeRegex).thenReturn('');
    when(() => mockConfig.excludeRegex).thenReturn('');
    when(() => mockConfig.maxResolution).thenReturn('4k');
    when(() => mockConfig.prioritizedLanguages).thenReturn([]);
    when(() => mockConfig.preferHDR).thenReturn(false);
    when(() => mockConfig.preferEncrypted).thenReturn(false);
    when(() => mockConfig.neuroLinkEnabled).thenReturn(false);
    when(() => mockConfig.requireDetailsForOriginal).thenReturn(false);
    when(() => mockConfig.appendOriginalDesc).thenReturn(false);
    when(() => mockConfig.seriesTitleCleanup).thenReturn(true);
    when(() => mockConfig.preferredSourceType).thenReturn('torrent');
    when(
      () => mockConfig.getOrionApiKey(),
    ).thenAnswer((_) async => 'orion_token');
    when(
      () => mockConfig.getPremiumizeApiKey(),
    ).thenAnswer((_) async => 'prem_token');
    when(
      () => mockConfig.getAllDebridApiKey(),
    ).thenAnswer((_) async => 'ad_token');

    when(() => mockTrackerService.getTrackers()).thenAnswer((_) async => []);

    aggregator = StreamAggregator(
      config: mockConfig,
      trackerService: mockTrackerService,
      cortex: mockCortexService,
    );
  });

  group('StreamAggregator Content Integrity', () {
    final rawResults = [
      {
        'title': 'The Mandalorian S02E03 1080p',
        'infoHash': 'hash1',
        'magnet': 'magnet:?xt=urn:btih:hash1&dn=The.Mandalorian.S02E03.1080p',
      },
      {
        'title': 'The Mandalorian S02E04 1080p',
        'infoHash': 'hash2',
        'magnet': 'magnet:?xt=urn:btih:hash2&dn=The.Mandalorian.S02E04.1080p',
      },
      {
        'title': 'The Mandalorian S01E03 720p',
        'infoHash': 'hash3',
        'magnet': 'magnet:?xt=urn:btih:hash3&dn=The.Mandalorian.S01E03.720p',
      },
      {
        'title': 'Blade Runner 1982 Final Cut',
        'infoHash': 'hash4',
        'magnet': 'magnet:?xt=urn:btih:hash4&dn=Blade.Runner.1982.Final.Cut',
      },
      {
        'title': 'Blade Runner 2049 4K',
        'infoHash': 'hash5',
        'magnet': 'magnet:?xt=urn:btih:hash5&dn=Blade.Runner.2049.4K',
      },
    ];

    test('Series: Filter by Season/Episode and Title Similarity', () async {
      final streams = await aggregator.aggregateStreams(
        rawResults,
        type: 'series',
        season: 2,
        episode: 3,
        requestedTitle: 'The Mandalorian',
      );

      expect(streams.length, 1);
      expect(streams.first['title'], contains('S02E03'));
      expect(streams.any((s) => s['title'].contains('Blade Runner')), isFalse);
    });

    test('Movie: Filter by Year and Title Similarity', () async {
      final streams = await aggregator.aggregateStreams(
        rawResults,
        type: 'movie',
        year: 1982,
        requestedTitle: 'Blade Runner',
      );

      expect(streams.length, 1);
      expect(streams.first['title'], contains('1982'));
    });

    test('Movie: Allow ±1 Year', () async {
      final resultsWithOffYear = [
        ...rawResults,
        {
          'title': 'Movie 2022',
          'infoHash': 'hash6',
          'magnet': 'magnet:?xt=urn:btih:hash6&dn=Movie.2022',
        },
      ];
      final streams = await aggregator.aggregateStreams(
        resultsWithOffYear,
        type: 'movie',
        year: 2023,
      );

      expect(streams.any((s) => s['title'].contains('2022')), isTrue);
    });

    test(
      'Series: Ignore filter if parsing fails but keep if no SE found',
      () async {
        final resultsWithNoSE = [
          ...rawResults,
          {
            'title': 'The Mandalorian Special',
            'infoHash': 'hash7',
            'magnet': 'magnet:?xt=urn:btih:hash7&dn=The.Mandalorian.Special',
          },
        ];
        final streams = await aggregator.aggregateStreams(
          resultsWithNoSE,
          type: 'series',
          season: 2,
          episode: 3,
        );

        expect(streams.any((s) => s['infoHash'] == 'hash1'), isTrue);
        expect(streams.any((s) => s['infoHash'] == 'hash7'), isTrue);
        expect(streams.any((s) => s['infoHash'] == 'hash2'), isFalse);
      },
    );
  });
}

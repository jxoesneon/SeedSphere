import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/core/stream_aggregator.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/cortex_service.dart';
import 'package:gardener/core/tracker_service.dart';
import 'package:gardener/scrapers/scraper_engine.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockCortexService extends Mock implements CortexService {}

class MockStreamResolver extends Mock implements StreamResolver {}

class MockScraperEngine extends Mock implements ScraperEngine {}

class MockTrackerService extends Mock implements TrackerService {}

void main() {
  late MockConfigManager mockConfig;
  late MockCortexService mockCortex;
  late MockStreamResolver mockResolver;
  late MockScraperEngine mockScraper;
  late MockTrackerService mockTracker;
  late StreamAggregator aggregator;

  setUp(() {
    mockConfig = MockConfigManager();
    mockCortex = MockCortexService();
    mockResolver = MockStreamResolver();
    mockScraper = MockScraperEngine();
    mockTracker = MockTrackerService();

    when(() => mockConfig.autoProxy).thenReturn(true);
    when(() => mockConfig.maxTrackers).thenReturn(0);
    when(() => mockConfig.preferEncrypted).thenReturn(false);
    when(() => mockConfig.excludeCam).thenReturn(false);
    when(() => mockConfig.exclude3D).thenReturn(false);
    when(() => mockConfig.includeRegex).thenReturn('');
    when(() => mockConfig.excludeRegex).thenReturn('');
    when(() => mockConfig.maxResolution).thenReturn('4k');
    when(() => mockConfig.neuroLinkEnabled).thenReturn(false);
    when(() => mockConfig.sortBy).thenReturn('Resolution');
    when(() => mockConfig.preferHDR).thenReturn(false);
    when(() => mockConfig.prioritizedLanguages).thenReturn(['Spanish']);
    when(() => mockConfig.requireDetailsForOriginal).thenReturn(false);
    when(() => mockConfig.appendOriginalDesc).thenReturn(false);
    when(() => mockConfig.seriesTitleCleanup).thenReturn(true);
    when(() => mockConfig.preferredSourceType).thenReturn('Any');
    when(() => mockConfig.enableTrackerScraping).thenReturn(true);
    when(() => mockConfig.trackerScrapeTimeoutMs).thenReturn(1000);
    when(() => mockConfig.maxResultsPerProvider).thenReturn(15);

    when(() => mockTracker.getTrackers()).thenAnswer((_) async => []);

    aggregator = StreamAggregator(
      trackerService: mockTracker,
      config: mockConfig,
      cortex: mockCortex,
    );
  });

  group('Heuristic Gap Closure Verification', () {
    test('StreamAggregator ranks prioritized language higher', () async {
      final List<Map<String, dynamic>> results = [
        {
          'magnet': 'magnet:?xt=urn:btih:hash1',
          'title': 'Movie.2023.1080p.English.AC3',
          'seeders': 100,
        },
        {
          'magnet': 'magnet:?xt=urn:btih:hash2',
          'title': 'Movie.2023.1080p.Spanish.AC3',
          'seeders': 10,
        },
      ];

      final aggregated = await aggregator.aggregateStreams(results);

      // Spanish should be first due to priority, despite lower seeds
      expect(aggregated.first['infoHash'], 'hash2');
      expect(aggregated.last['infoHash'], 'hash1');
    });

    test('StreamAggregator deduplicates results by infoHash', () async {
      final List<Map<String, dynamic>> results = [
        {
          'magnet': 'magnet:?xt=urn:btih:hash1',
          'title': 'Movie.1080p',
          'seeders': 10,
        },
        {
          'magnet': 'magnet:?xt=urn:btih:hash1', // Duplicate
          'title': 'Movie.1080p',
          'seeders': 20, // Better seeds
        },
      ];

      final aggregated = await aggregator.aggregateStreams(results);

      expect(aggregated.length, 1);
      expect(aggregated.first['seeders'], 20);
    });

    test('StremioServer correctly parses skip parameter', () async {
      final server = StremioServer(
        resolver: mockResolver,
        scrapers: mockScraper,
      );
      final catalog = await server.getCatalog('movie', 'seedsphere.recent', {
        'skip': '10',
      });
      expect(catalog['metas'], isEmpty);
    });
  });
}

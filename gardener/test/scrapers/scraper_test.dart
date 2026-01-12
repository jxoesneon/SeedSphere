import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/scrapers/yts_scraper.dart';
import 'package:gardener/scrapers/torrentio_scraper.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/metadata_normalizer.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

class MockConfigManager extends Mock implements ConfigManager {}

void main() {
  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    registerFallbackValue(Uri());
  });

  group('MetadataNormalizer', () {
    test('Standardizes 4K resolution', () {
      final raw = {'title': 'Sintel 2010 2160p', 'hash': 'abc'};
      final normalized = MetadataNormalizer.normalize(raw);
      expect(normalized['quality'], '2160p');
      expect(
        normalized['infohash'],
        null,
      ); // Normalized expects valid hash or extracts
    });

    test('Standardizes 1080p resolution', () {
      final raw = {'title': 'Sintel 2010 1080p', 'hash': 'abc'};
      final normalized = MetadataNormalizer.normalize(raw);
      expect(normalized['quality'], '1080p');
    });
  });

  group('YTSScraper', () {
    test('Parses movies correctly', () async {
      final mockJson = {
        'data': {
          'movie_count': 1,
          'movies': [
            {
              'title': 'Test Movie',
              'torrents': [
                {
                  'quality': '1080p',
                  'type': 'bluray',
                  'hash': 'hash123',
                  'seeds': 100,
                  'size': '2GB',
                },
              ],
            },
          ],
        },
      };

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final scraper = YTSScraper(client: mockClient);
      final results = await scraper.scrape('Test Movie');

      expect(results.length, 1);
      expect(results[0]['infoHash'], 'hash123');
      expect(results[0]['seeders'], 100);
    });

    test('Handles API errors gracefully', () async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final scraper = YTSScraper(client: mockClient);
      final results = await scraper.scrape('Test Movie');

      expect(results, isEmpty);
    });
  });

  group('TorrentioScraper', () {
    test('Parses streams correctly', () async {
      final mockJson = {
        'streams': [
          {
            'title': 'Test Stream \n 4K',
            'name': 'Torrentio',
            'infoHash': 'hashTor',
            'fileIdx': 0,
          },
        ],
      };

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final scraper = TorrentioScraper(client: mockClient);
      final results = await scraper.scrape('tt1234567');

      expect(results.length, 1);
      expect(results[0]['infoHash'], 'hashTor');
      expect(results[0]['fileIdx'], 0);
    });

    test('Handles errors', () async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response('Error', 404));

      final scraper = TorrentioScraper(client: mockClient);
      final results = await scraper.scrape('tt1');
      expect(results, isEmpty);
    });
  });

  group('ScraperEngine', () {
    test('Aggregates results from multiple scrapers', () async {
      final mockConfig = MockConfigManager();
      when(() => mockConfig.probeProviders).thenReturn(false);
      when(() => mockConfig.maxResultsPerProvider).thenReturn(15);
      when(() => mockConfig.providerFetchTimeoutMs).thenReturn(5000);
      when(() => mockConfig.enableTrackerScraping).thenReturn(false);
      when(() => mockConfig.enableYts).thenReturn(true);
      when(() => mockConfig.enableTorrentio).thenReturn(true);
      when(() => mockConfig.enableEztv).thenReturn(true);
      when(() => mockConfig.enableNyaa).thenReturn(true);
      when(() => mockConfig.enable1337x).thenReturn(true);
      when(() => mockConfig.enablePirateBay).thenReturn(true);
      when(() => mockConfig.enableTorrentGalaxy).thenReturn(true);
      when(() => mockConfig.enableTorlock).thenReturn(true);
      when(() => mockConfig.enableMagnetDL).thenReturn(true);
      when(() => mockConfig.enableAniDex).thenReturn(true);
      when(() => mockConfig.enableTokyoTosho).thenReturn(true);
      when(() => mockConfig.enableZooqle).thenReturn(true);
      when(() => mockConfig.enableRutor).thenReturn(true);
      when(() => mockConfig.enableTorznab).thenReturn(true);

      final mockJson1 = {
        'data': {
          'movie_count': 1,
          'movies': [
            {
              'title': 'Movie A',
              'torrents': [
                {'hash': 'h1', 'seeds': 10, 'size': '1GB', 'quality': '1080p'},
              ],
            },
          ],
        },
      };

      final mockJson2 = {
        'streams': [
          {'title': 'Stream B', 'infoHash': 'h2', 'seeders': 20},
        ],
      };

      // Mock client to return different responses based on URL
      when(() => mockClient.get(any())).thenAnswer((inv) async {
        final url = (inv.positionalArguments[0] as Uri).toString();
        if (url.contains('yts')) {
          return http.Response(jsonEncode(mockJson1), 200);
        }
        if (url.contains('torrentio')) {
          return http.Response(jsonEncode(mockJson2), 200);
        }
        return http.Response('Not Found', 404);
      });

      final s1 = YTSScraper(client: mockClient);
      final s2 = TorrentioScraper(client: mockClient);

      final engine = ScraperEngine(scrapers: [s1, s2], config: mockConfig);

      final results = await engine.scrapeAll('test');
      expect(results.length, 2);
      expect(results.any((r) => r['infoHash'] == 'h1'), true);
      expect(results.any((r) => r['infoHash'] == 'h2'), true);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

class MockAppConfig extends Mock implements AppConfig {}

void main() {
  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    registerFallbackValue(Uri());
  });

  group('MetadataNormalizer', () {
    test('Standardizes 4K resolution', () {
      final raw = {'title': 'Sintel 2010 2160p', 'hash': 'abc'};
      final normalized = MetadataNormalizer.normalize(raw, 'Test');
      expect(normalized.resolution, '4K');
      expect(normalized.infoHash, 'abc');
    });

    test('Standardizes 1080p resolution', () {
      final raw = {'title': 'Sintel 2010 1080p', 'hash': 'abc'};
      final normalized = MetadataNormalizer.normalize(raw, 'Test');
      expect(normalized.resolution, '1080p');
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
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final scraper = YTSScraper(client: mockClient);
      final results = await scraper.scrape('Test Movie');

      expect(results.length, 1);
      expect(results[0]['infoHash'], 'hash123');
      expect(results[0]['seeders'], 100);
    });

    test('Handles API errors gracefully', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
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
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final scraper = TorrentioScraper(client: mockClient);
      final results = await scraper.scrape('tt1234567');

      expect(results.length, 1);
      expect(results[0]['infoHash'], 'hashTor');
      expect(results[0]['fileIdx'], 0);
    });

    test('Handles errors', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('Error', 404));

      final scraper = TorrentioScraper(client: mockClient);
      final results = await scraper.scrape('tt1');
      expect(results, isEmpty);
    });
  });

  group('ScraperEngine', () {
    test('Aggregates results from multiple scrapers', () async {
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

      when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
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

      final engine = ScraperEngine(scrapers: [s1, s2]);

      final results = await engine.scrapeAll('test');
      expect(results.length, 2);
      expect(results.any((r) => r['infoHash'] == 'h1'), true);
      expect(results.any((r) => r['infoHash'] == 'h2'), true);
    });
  });
}

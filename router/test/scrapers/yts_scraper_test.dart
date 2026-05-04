import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/scrapers/yts_scraper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@GenerateNiceMocks([MockSpec<http.Client>()])
import 'yts_scraper_test.mocks.dart';

void main() {
  late YTSScraper scraper;
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
    scraper = YTSScraper(client: mockClient);
  });

  group('YTSScraper', () {
    test('scrape handles successful response', () async {
      final mockJson = {
        'status': 'ok',
        'data': {
          'movie_count': 1,
          'movies': [
            {
              'title': 'Inception',
              'torrents': [
                {'hash': 'abc', 'quality': '1080p', 'type': 'bluray', 'seeds': 100, 'size': '2GB'}
              ]
            }
          ]
        }
      };

      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final results = await scraper.scrape('tt1375666');
      expect(results, hasLength(1));
      expect(results[0]['title'], contains('Inception'));
      expect(results[0]['infoHash'], 'abc');
    });

    test('scrape handles no movies found', () async {
      final mockJson = {
        'status': 'ok',
        'data': {'movie_count': 0}
      };

      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response(jsonEncode(mockJson), 200));

      final results = await scraper.scrape('tt0000000');
      expect(results, isEmpty);
    });
  });
}

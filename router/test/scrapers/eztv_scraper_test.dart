import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scrapers/eztv_scraper.dart';
import 'package:test/test.dart';

void main() {
  group('EztvScraper', () {
    late EztvScraper scraper;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        // EZTV API Mock
        if (request.url.host.contains('eztv')) {
          return http.Response(
            jsonEncode({
              'torrents': [
                {
                  'title': 'Test Show S01E01',
                  'magnet_url': 'magnet:?xt=urn:btih:eztvhash123&dn=Test',
                  'hash': 'eztvhash123',
                  'seeds': 100,
                  'peers': 50,
                  'size_bytes': 1024,
                },
                {
                  'title': 'Bad Entry', // No magnet
                },
              ],
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      scraper = EztvScraper(client: mockClient);
    });

    test('scrape returns results', () async {
      final results = await scraper.scrape('tt12345');
      expect(results, isNotEmpty);
      expect(results.length, 1);
      expect(results.first['title'], 'Test Show S01E01');
      expect(results.first['infoHash'], 'eztvhash123');
      expect(results.first['provider'], 'EZTV');
    });
  });
}

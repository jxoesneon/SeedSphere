import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scrapers/nyaa_scraper.dart';
import 'package:test/test.dart';

void main() {
  group('NyaaScraper', () {
    late NyaaScraper scraper;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.host.contains('cinemeta')) {
          return http.Response(
            jsonEncode({
              'meta': {'name': 'Anime Show'},
            }),
            200,
          );
        }

        if (request.url.host.contains('nyaa.si')) {
          return http.Response('''
            <html>
              <body>
                <a href="magnet:?xt=urn:btih:1111111111111111111111111111111111111111&dn=Anime">Download</a>
                <a href="magnet:?xt=urn:btih:2222222222222222222222222222222222222222&dn=Anime2">Download 2</a>
              </body>
            </html>
            ''', 200);
        }
        return http.Response('', 404);
      });

      scraper = NyaaScraper(client: mockClient);
    });

    test('scrape returns results', () async {
      final results = await scraper.scrape('ttanime');
      expect(results.length, 2);
      expect(
        results.first['infoHash'],
        '1111111111111111111111111111111111111111',
      );
      expect(results.first['provider'], 'Nyaa');
    });
  });
}

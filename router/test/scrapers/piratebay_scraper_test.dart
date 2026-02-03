import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scrapers/piratebay_scraper.dart';
import 'package:test/test.dart';

void main() {
  group('PirateBayScraper', () {
    late PirateBayScraper scraper;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        // Cinemeta Mock
        if (request.url.host.contains('cinemeta')) {
          return http.Response(
            jsonEncode({
              'meta': {'name': 'Big Buck Bunny', 'year': '2008'},
            }),
            200,
          );
        }

        // TPB Mock
        if (request.url.host.contains('thepiratebay')) {
          if (request.url.path.contains('/search/')) {
            return http.Response('''
              <html>
                <body>
                  <table>
                    <tr>
                      <td><a class="detLink" title="Details for Big Buck Bunny" href="/torrent/123">Big Buck Bunny</a></td>
                      <td><a href="magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Big+Buck+Bunny">Magnet 1</a></td>
                    </tr>
                    <tr>
                      <td><a class="detLink" title="Details for Big Buck Bunny HD" href="/torrent/456">Big Buck Bunny HD</a></td>
                      <td><a href="magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12&dn=Big+Buck+Bunny+HD">Magnet 2</a></td>
                    </tr>
                  </table>
                </body>
              </html>
              ''', 200);
          }
        }

        return http.Response('', 404);
      });

      scraper = PirateBayScraper(client: mockClient);
    });

    test('scrape returns results', () async {
      final results = await scraper.scrape('tt1254207');
      expect(results, isNotEmpty);
      expect(results.length, 2);
      expect(results.first['title'], 'Big Buck Bunny');
      expect(results.first['provider'], 'PirateBay');
      expect(
        results.first['infoHash'],
        '1234567890abcdef1234567890abcdef12345678',
      );
    });

    test('scrape returns empty on error', () async {
      final errorClient = MockClient((_) async => http.Response('', 500));
      final errorScraper = PirateBayScraper(client: errorClient);
      final results = await errorScraper.scrape('tt1254207');
      expect(results, isEmpty);
    });
  });
}

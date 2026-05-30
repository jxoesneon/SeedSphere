import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:test/test.dart';

void main() {
  group('PirateBayScraper', () {
    late PirateBayScraper scraper;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.host.contains('cinemeta')) {
          return http.Response(
            jsonEncode({
              'meta': {'name': 'Big Buck Bunny', 'year': 2008},
            }),
            200,
          );
        }

        if (request.url.host.contains('thepiratebay')) {
          return http.Response('''
            <html>
              <body>
                <table>
                  <tr>
                    <td><a class="detLink" title="Details for Big Buck Bunny" href="/torrent/123">Big Buck Bunny</a></td>
                    <td><a href="magnet:?xt=urn:btih:1111111111111111111111111111111111111111&dn=Big+Buck+Bunny">Magnet 1</a></td>
                    <td align="right">10</td>
                  </tr>
                </table>
              </body>
            </html>
            ''', 200);
        }
        return http.Response('', 404);
      });

      scraper = PirateBayScraper(client: mockClient);
    });

    test('scrape returns results', () async {
      final results = await scraper.scrape('tt1254207', title: 'Big Buck Bunny', year: 2008);
      expect(results, isNotEmpty);
      expect(results.first['seeders'], 10);
      expect(results.first['provider'], 'PirateBay');
    });

    test('scrape returns empty on error', () async {
      final errorClient = MockClient((_) async => http.Response('', 500));
      final errorScraper = PirateBayScraper(client: errorClient);
      final results = await errorScraper.scrape('tt1254207', title: 'Error');
      expect(results, isEmpty);
    });
  });
}

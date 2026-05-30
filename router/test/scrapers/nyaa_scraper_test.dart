import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
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
                <table>
                  <tr>
                    <td><a href="magnet:?xt=urn:btih:1111111111111111111111111111111111111111&dn=Test+Anime+S01E01">Download</a></td>
                    <td class="text-center">1 GB</td>
                    <td class="text-center">2024-01-01</td>
                    <td class="text-center">10</td>
                    <td class="text-center">5</td>
                    <td class="text-center">0</td>
                  </tr>
                  <tr>
                    <td><a href="magnet:?xt=urn:btih:2222222222222222222222222222222222222222&dn=Test+Anime+S01E02">Download 2</a></td>
                    <td class="text-center">1 GB</td>
                    <td class="text-center">2024-01-01</td>
                    <td class="text-center">20</td>
                    <td class="text-center">5</td>
                    <td class="text-center">0</td>
                  </tr>
                </table>
              </body>
            </html>
            ''', 200);
        }
        return http.Response('', 404);
      });

      scraper = NyaaScraper(client: mockClient);
    });

    test('scrape returns results', () async {
      final results = await scraper.scrape('ttanime', title: 'Test Anime');
      expect(results.length, 2);
      expect(
        results.first['infoHash'],
        '1111111111111111111111111111111111111111',
      );
      expect(results.first['provider'], 'Nyaa');
      expect(results.first['seeders'], 10);
    });
  });
}

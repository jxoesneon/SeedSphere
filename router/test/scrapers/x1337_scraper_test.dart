import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:test/test.dart';

void main() {
  group('X1337Scraper', () {
    late X1337Scraper scraper;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.host.contains('cinemeta')) {
          return http.Response(
            jsonEncode({
              'meta': {'name': 'The Matrix', 'year': 1999},
            }),
            200,
          );
        }

        if (request.url.host.contains('1337x') || request.url.host.contains('1377x')) {
          final path = request.url.path;
          if (path.contains('/search/')) {
            return http.Response('''
              <html>
                <body>
                  <a href="/torrent/123/TheMatrix/">The Matrix 1999 1080p</a>
                </body>
              </html>
            ''', 200);
          }
          if (path.contains('/torrent/')) {
            return http.Response('''
              <html>
                <body>
                  <a href="magnet:?xt=urn:btih:1111111111111111111111111111111111111111&dn=The+Matrix+1999+1080p">Magnet</a>
                </body>
              </html>
            ''', 200);
          }
        }
        return http.Response('', 404);
      });

      scraper = X1337Scraper(client: mockClient);
    });

    test('scrape follows links and returns magnets', () async {
      final results = await scraper.scrape('ttmovie', title: 'The Matrix', year: 1999);
      // "The Matrix 1999 1080p" matches "The Matrix" (1999) -> Pass
      // "The Matrix Reloaded" matches "The Matrix" -> Fails word check or safe extras (Reloaded)
      expect(results, isNotEmpty);
      expect(results.first['provider'], '1337x');
    });
  });
}

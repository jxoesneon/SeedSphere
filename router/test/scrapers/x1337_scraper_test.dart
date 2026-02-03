import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scrapers/x1337_scraper.dart';
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
              'meta': {'name': 'Specific Movie'},
            }),
            200,
          );
        }

        // Search Page
        if (request.url.path.contains('/search/')) {
          return http.Response('''
            <html>
              <a href="/torrent/123/Specific-Movie/">Link</a>
              <a href="/torrent/456/Specific-Movie-Director-Cut/">Link 2</a>
            </html>
            ''', 200);
        }

        // Detail Page
        if (request.url.path.contains('/torrent/')) {
          final hash = request.url.path.contains('123')
              ? '1111111111111111111111111111111111111111'
              : '2222222222222222222222222222222222222222';
          return http.Response('''
             <html>
                <a href="magnet:?xt=urn:btih:$hash&dn=Specific+Movie">Magnet</a>
             </html>
             ''', 200);
        }

        return http.Response('', 404);
      });

      scraper = X1337Scraper(client: mockClient);
    });

    test('scrape follows links and returns magnets', () async {
      final results = await scraper.scrape('ttmovie');
      expect(results.length, 2);
      expect(
        results.any(
          (r) => r['infoHash'] == '1111111111111111111111111111111111111111',
        ),
        isTrue,
      );
      expect(
        results.any(
          (r) => r['infoHash'] == '2222222222222222222222222222222222222222',
        ),
        isTrue,
      );
      expect(results.first['provider'], '1337x');
    });
  });
}

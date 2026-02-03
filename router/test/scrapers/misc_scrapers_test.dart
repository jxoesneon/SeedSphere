import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scrapers/magnetdl_scraper.dart';
import 'package:router/scrapers/anidex_scraper.dart';
import 'package:router/scrapers/zooqle_scraper.dart';
import 'package:router/scrapers/tokyotosho_scraper.dart';
import 'package:router/scrapers/rutor_scraper.dart';
import 'package:router/scrapers/torlock_scraper.dart';
import 'package:router/scrapers/torrentgalaxy_scraper.dart';
import 'package:test/test.dart';

// Helper to generate a valid magnet with given hash
String makeHtml(String hash, {String provider = 'Provider'}) {
  return '''
    <html>
      <body>
        <a href="magnet:?xt=urn:btih:$hash&dn=Test">Download</a>
      </body>
    </html>
  ''';
}

void main() {
  final longHash = '1111111111111111111111111111111111111111';

  group('MiscScrapers', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.host.contains('cinemeta')) {
          return http.Response(
            jsonEncode({
              'meta': {'name': 'Test Title'},
            }),
            200,
          );
        }

        // Generic Scraper Response
        // Most scrapers search by query params or path.
        // We just return HTML with a valid magnet.
        if (request.url.path.contains('/') ||
            request.url.queryParameters.isNotEmpty) {
          return http.Response(makeHtml(longHash), 200);
        }

        return http.Response('', 404);
      });
    });

    test('MagnetDLScraper', () async {
      final s = MagnetDLScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'MagnetDL');
      expect(r.first['infoHash'], longHash);
    });

    test('AnidexScraper', () async {
      final s = AnidexScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'AniDex');
    });

    test('ZooqleScraper', () async {
      final s = ZooqleScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'Zooqle');
    });

    test('TokyoToshoScraper', () async {
      final s = TokyoToshoScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'TokyoTosho');
    });

    test('RutorScraper', () async {
      final s = RutorScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'Rutor');
    });

    test('TorlockScraper', () async {
      final s = TorlockScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'Torlock');
    });

    test('TorrentGalaxyScraper', () async {
      final s = TorrentGalaxyScraper(client: mockClient);
      final r = await s.scrape('tt123');
      expect(r, isNotEmpty);
      expect(r.first['provider'], 'TorrentGalaxy');
    });
  });
}

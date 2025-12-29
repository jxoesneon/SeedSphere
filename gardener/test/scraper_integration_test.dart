import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/scrapers/eztv_scraper.dart';
import 'package:gardener/scrapers/nyaa_scraper.dart';
import 'package:gardener/scrapers/x1337_scraper.dart';
import 'package:gardener/scrapers/anidex_scraper.dart';
import 'package:gardener/scrapers/magnetdl_scraper.dart';
import 'package:gardener/scrapers/piratebay_scraper.dart';
import 'package:gardener/scrapers/rutor_scraper.dart';
import 'package:gardener/scrapers/tokyotosho_scraper.dart';
import 'package:gardener/scrapers/torlock_scraper.dart';
import 'package:gardener/scrapers/torrentgalaxy_scraper.dart';
import 'package:gardener/scrapers/zooqle_scraper.dart';

void main() {
  group('Scraper Integration Tests', () {
    test('EZTV Scraper initializes and forms correct URLs', () async {
      final scraper = EztvScraper();
      expect(scraper.baseUrl, contains('eztv.re'));
      expect(scraper.name, 'EZTV');
    });

    test('Nyaa Scraper initializes', () async {
      final scraper = NyaaScraper();
      expect(scraper.baseUrl, contains('nyaa.si'));
      expect(scraper.name, 'Nyaa');
    });

    test('1337x Scraper initializes', () async {
      final scraper = X1337Scraper();
      expect(scraper.baseUrl, contains('1377x.to')); // Default mirror
      expect(scraper.name, '1337x');
    });

    test('PirateBay Scraper initializes', () async {
      final scraper = PirateBayScraper();
      expect(scraper.baseUrl, contains('thepiratebay.org'));
      expect(scraper.name, 'Pirate Bay');
    });

    test('TorrentGalaxy Scraper initializes', () async {
      final scraper = TorrentGalaxyScraper();
      expect(scraper.baseUrl, contains('torrentgalaxy'));
      expect(scraper.name, 'TorrentGalaxy');
    });

    test('Torlock Scraper initializes', () async {
      final scraper = TorlockScraper();
      expect(scraper.baseUrl, contains('torlock.com'));
      expect(scraper.name, 'Torlock');
    });

    test('MagnetDL Scraper initializes', () async {
      final scraper = MagnetDLScraper();
      expect(scraper.baseUrl, contains('magnetdl.com'));
      expect(scraper.name, 'MagnetDL');
    });

    test('Anidex Scraper initializes', () async {
      final scraper = AnidexScraper();
      expect(scraper.baseUrl, contains('anidex.info'));
      expect(scraper.name, 'AniDex');
    });

    test('TokyoTosho Scraper initializes', () async {
      final scraper = TokyoToshoScraper();
      expect(scraper.baseUrl, contains('tokyotosho.info'));
      expect(scraper.name, 'TokyoTosho');
    });

    test('Zooqle Scraper initializes', () async {
      final scraper = ZooqleScraper();
      expect(scraper.baseUrl, contains('zooqle.com'));
      expect(scraper.name, 'Zooqle');
    });

    test('Rutor Scraper initializes', () async {
      final scraper = RutorScraper();
      expect(scraper.baseUrl, contains('rutor.info'));
      expect(scraper.name, 'Rutor');
    });
  });
}

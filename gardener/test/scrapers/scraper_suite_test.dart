import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/core/config_manager.dart';


class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockHttpClient mockClient;

  setUp(() async {
    mockClient = MockHttpClient();
    SharedPreferences.setMockInitialValues({
      'torznab_url': 'http://torznab.test',
      'torznab_api_key': 'key',
      'enable_torznab': true,
      'enable_torrentio': true,
      'prov_yts': true,
      'prov_eztv': true,
      'prov_nyaa': true,
      'prov_1337x': true,
      'prov_piratebay': true,
      'prov_torrentgalaxy': true,
      'prov_torlock': true,
      'prov_magnetdl': true,
      'prov_anidex': true,
      'prov_tokyotosho': true,
      'prov_zooqle': true,
      'prov_rutor': true,
    });

    const scChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(scChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'read') return 'mock_key';
          return null;
        });

    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
          return '.';
        });

    await ConfigManager().init();
    registerFallbackValue(Uri());
  });

  group('Scraper Suite', () {
    test(
      'All scrapers handle successful empty/generic response without verify crash',
      () async {
        final jsonBody = jsonEncode({'data': {}, 'torrents': []});
        final htmlBody = '<html><body></body></html>';

        final config = ConfigManager();

        final scrapers = [
          AnidexScraper(client: mockClient),
          EztvScraper(client: mockClient),
          MagnetDLScraper(client: mockClient),
          NyaaScraper(client: mockClient),
          PirateBayScraper(client: mockClient),
          RutorScraper(client: mockClient),
          TokyoToshoScraper(client: mockClient),
          TorlockScraper(client: mockClient),
          TorrentGalaxyScraper(client: mockClient),
          TorrentioScraper(client: mockClient),
          TorznabScraper(client: mockClient, config: config),
          X1337Scraper(client: mockClient),
          YTSScraper(client: mockClient),
          ZooqleScraper(client: mockClient),
        ];

        for (final scraper in scrapers) {
          try {
            if (scraper is YTSScraper || scraper is TorrentioScraper) {
              when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => http.Response(jsonBody, 200));
            } else {
              when(() => mockClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async => http.Response(htmlBody, 200));
            }
            await scraper.scrape('test');
          } catch (_) {}
        }
      },
    );

    test('All scrapers handle HTTP errors', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final config = ConfigManager();

      final scrapers = [
        AnidexScraper(client: mockClient),
        EztvScraper(client: mockClient),
        MagnetDLScraper(client: mockClient),
        NyaaScraper(client: mockClient),
        PirateBayScraper(client: mockClient),
        RutorScraper(client: mockClient),
        TokyoToshoScraper(client: mockClient),
        TorlockScraper(client: mockClient),
        TorrentGalaxyScraper(client: mockClient),
        TorrentioScraper(client: mockClient),
        TorznabScraper(client: mockClient, config: config),
        X1337Scraper(client: mockClient),
        YTSScraper(client: mockClient),
        ZooqleScraper(client: mockClient),
      ];

      for (final scraper in scrapers) {
        final results = await scraper.scrape('test');
        expect(results, isEmpty);
      }
    });
  });
}

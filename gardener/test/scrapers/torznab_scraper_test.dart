import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/torznab_scraper.dart';
import 'package:gardener/core/config_manager.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockConfigManager extends Mock implements ConfigManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockHttpClient mockClient;
  late MockConfigManager mockConfig;
  late TorznabScraper scraper;

  setUp(() {
    mockClient = MockHttpClient();
    mockConfig = MockConfigManager();
    scraper = TorznabScraper(client: mockClient, config: mockConfig);

    registerFallbackValue(Uri());
    when(() => mockConfig.torznabUrl).thenReturn('http://torznab.test');
    when(() => mockConfig.getTorznabKey()).thenAnswer((_) async => 'mock_key');
  });

  group('TorznabScraper', () {
    test('scrape returns results from valid XML', () async {
      const xmlResponse = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2010/book.xsd">
  <channel>
    <item>
      <title>Test Movie 2023 1080p</title>
      <link>magnet:?xt=urn:btih:TESTHASH</link>
      <torznab:attr name="seeders" value="100"/>
      <torznab:attr name="peers" value="50"/>
      <size>2147483648</size>
    </item>
  </channel>
</rss>
''';

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(xmlResponse, 200));

      final results = await scraper.scrape('tt1234567');

      expect(results, isNotEmpty);
      expect(results.first['title'], contains('Test Movie'));
      expect(results.first['infoHash'], equals('testhash'));
      expect(results.first['seeders'], equals(100));
    });

    test('scrape handles empty results', () async {
      const xmlResponse = '<?xml version="1.0"?><rss><channel></channel></rss>';
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(xmlResponse, 200));

      final results = await scraper.scrape('tt1234567');
      expect(results, isEmpty);
    });

    test('scrape handles HTTP failure', () async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response('Error', 500));

      final results = await scraper.scrape('tt1234567');
      expect(results, isEmpty);
    });

    test('isEnabled checks config', () {
      when(() => mockConfig.enableTorznab).thenReturn(true);
      expect(scraper.isEnabled(mockConfig), isTrue);

      when(() => mockConfig.enableTorznab).thenReturn(false);
      expect(scraper.isEnabled(mockConfig), isFalse);
    });
  });
}

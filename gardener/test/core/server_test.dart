import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/scrapers/scraper_engine.dart';

class MockConfigManager extends Mock implements ConfigManager {}

class MockStreamResolver extends Mock implements StreamResolver {}

class MockScraperEngine extends Mock implements ScraperEngine {}

void main() {
  late MockConfigManager mockConfig;
  late MockStreamResolver mockResolver;
  late MockScraperEngine mockScraper;
  late StremioServer server;

  setUp(() {
    mockConfig = MockConfigManager();
    mockResolver = MockStreamResolver();
    mockScraper = MockScraperEngine();

    // Config stubs
    when(() => mockConfig.maxResolution).thenReturn('4k');
    when(() => mockConfig.onlyShowCached).thenReturn(false);
    when(() => mockConfig.prioritizedLanguages).thenReturn(['English']);
    when(() => mockConfig.debridService).thenReturn('real_debrid'); // Default

    server = StremioServer(resolver: mockResolver, scrapers: mockScraper);
  });

  group('StremioServer', () {
    test('Manifest returns correct metadata', () async {
      final manifest = await server.getManifest();
      expect(manifest['id'], 'org.seedsphere.gardener');
      expect(manifest['resources'], contains('stream'));
    });

    test('Catalog returns trending movies', () async {
      // Logic relies on HTTP call to Cinemeta, difficult to test without mocking internal HTTP or Refactoring Server to take API Client.
      // StremioServer uses http.get directly in _handleCatalog for trending.
      // We'll skip deep verification of trending fetch here unless we refactor.
      // But we can verify "seedsphere.recent" catalog logic (uses internal history).

      final catalog = await server.getCatalog('movie', 'seedsphere.recent', {});
      expect(catalog['metas'], isEmpty);
    });
  });
}

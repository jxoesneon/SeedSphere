import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'package:gardener/core/stream_aggregator.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStreamResolver extends Mock implements StreamResolver {}

class MockScraperEngine extends Mock implements ScraperEngine {}

class MockConfigManager extends Mock implements ConfigManager {}

class MockStreamAggregator extends Mock implements StreamAggregator {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  // We use regular flutter_test without TestWidgetsFlutterBinding to allow real HTTP.

  late StremioServer server;
  late MockStreamResolver mockResolver;
  late MockScraperEngine mockScrapers;
  late MockStreamAggregator mockAggregator;
  late MockHttpClient mockTelemetryClient;
  late MockConfigManager mockConfig;

  setUp(() async {
    mockResolver = MockStreamResolver();
    mockScrapers = MockScraperEngine();
    mockAggregator = MockStreamAggregator();
    mockTelemetryClient = MockHttpClient();
    mockConfig = MockConfigManager();

    // Stub ConfigManager defaults
    when(() => mockConfig.debridService).thenReturn('real_debrid');
    when(() => mockConfig.onlyShowCached).thenReturn(false);
    when(() => mockResolver.config).thenReturn(mockConfig);

    // Cache stubs
    when(() => mockAggregator.getCachedStreams(any())).thenReturn(null);
    when(() => mockAggregator.getStaleStreams(any())).thenReturn(null);

    // Mock SharedPreferences for ActivityManager/History
    SharedPreferences.setMockInitialValues({'user_id': 'test-user'});
    await ConfigManager().init();
    ActivityManager().setClient(mockTelemetryClient);

    // Telemetry usually succeeds or fails silently
    registerFallbackValue(Uri());
    when(
      () => mockTelemetryClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => http.Response('{}', 200));

    server = StremioServer(
      resolver: mockResolver,
      scrapers: mockScrapers,
      aggregator: mockAggregator,
    );
  });

  tearDown(() async {
    await server.stop();
  });

  group('StremioServer E2E Integration', () {
    test('Verifies full stream resolution flow', () async {
      const movieId = 'tt0133093'; // The Matrix
      const magnet = 'magnet:?xt=urn:btih:aabbcc&dn=TheMatrix';
      const directUrl = 'https://real-debrid.com/d/12345';

      // 1. Mock Scraper results
      final rawResults = [
        {
          'title': 'The Matrix 1080p',
          'magnet': magnet,
          'seeders': 100,
          'infoHash': 'aabbccddeeff0011',
        },
      ];
      when(
        () => mockScrapers.scrapeAll(movieId),
      ).thenAnswer((_) async => rawResults);

      // 2. Mock Aggregator behavior
      final aggregatedStreams = [
        {
          'title': 'The Matrix 1080p',
          'magnet': magnet,
          'infoHash': 'aabbccddeeff0011',
          'seeders': 100,
          'description': '🎥 The Matrix\n💿 1080P • x264\n👤 100 Seeds',
        },
      ];
      when(
        () => mockAggregator.aggregateStreams(
          any(),
          type: any(named: 'type'),
          imdbId: any(named: 'imdbId'),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          year: any(named: 'year'),
          requestedTitle: any(named: 'requestedTitle'),
        ),
      ).thenAnswer((_) async => aggregatedStreams);

      // 3. Mock Resolver behavior
      when(
        () => mockResolver.resolveStream(
          magnet,
          episodeMatcher: any(named: 'episodeMatcher'),
        ),
      ).thenAnswer((_) async => directUrl);

      // 3.5. Mock checkAvailability
      when(
        () => mockResolver.checkAvailability(any()),
      ).thenAnswer((_) async => {'aabbccddeeff0011': true});

      // 4. Start Server on ephemeral port to avoid parallel test conflicts
      await server.start(gardenerId: 'test-gardener', port: 0);
      final serverPort = server.port;

      // 5. Send Request
      // Use real http client to talk to local server
      final client = http.Client();
      final response = await client.get(
        Uri.parse('http://127.0.0.1:$serverPort/stream/movie/$movieId.json'),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);

      // 6. Verify Response
      expect(body['streams'], isNotEmpty);
      final stream = body['streams'][0];
      expect(stream['url'], directUrl);
      expect(stream['name'], contains('SeedSphere'));
      expect(stream['name'], contains('[RD+]'));
      expect(stream['title'], contains('The Matrix'));

      // Verify mocks were called
      verify(() => mockScrapers.scrapeAll(movieId)).called(1);
      verify(
        () => mockAggregator.aggregateStreams(
          rawResults,
          type: any(named: 'type'),
          imdbId: any(named: 'imdbId'),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          year: any(named: 'year'),
          requestedTitle: any(named: 'requestedTitle'),
        ),
      ).called(1);
      verify(
        () => mockResolver.resolveStream(
          magnet,
          episodeMatcher: any(named: 'episodeMatcher'),
        ),
      ).called(1);

      client.close();
    });
  });
}

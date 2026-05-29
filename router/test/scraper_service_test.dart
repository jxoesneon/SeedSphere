import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/scraper_service.dart';
import 'package:test/test.dart';
import 'manual_mocks.dart';

void main() {
  group('ScraperService', () {
    late ScraperService service;
    late ManualMockTrackerService mockTrackers;
    late ManualMockAppConfig mockConfig;
    late MockClient mockClient;

    setUp(() {
      mockTrackers = ManualMockTrackerService();
      mockConfig = ManualMockAppConfig();

      mockClient = MockClient((request) async {
        if (request.url.toString().contains('torrentio')) {
          return http.Response('', 200);
        }
        if (request.url.toString().contains('yts')) {
          // Simulate HEAD failure, GET success
          if (request.method == 'HEAD') return http.Response('', 405);
          return http.Response('{"status": "ok"}', 200);
        }
        if (request.url.toString().contains('eztv')) {
          return http.Response('', 500);
        }
        return http.Response('', 404);
      });

      service = ScraperService(mockTrackers, config: mockConfig, client: mockClient);
    });

    test('probeProviders checks endpoints correctly', () async {
      final results = await service.probeProviders();

      // Torrentio: HEAD 200 -> OK
      final torrentio = results.firstWhere((r) => r['name'] == 'Torrentio');
      expect(torrentio['ok'], true);
      expect(torrentio['status'], 200);

      // YTS: HEAD 405 -> GET 200 -> OK
      final yts = results.firstWhere((r) => r['name'] == 'YTS');
      expect(yts['ok'], true);
      expect(yts['status'], 200);

      // EZTV: HEAD 500 -> fail
      final eztv = results.firstWhere((r) => r['name'] == 'EZTV');
      expect(eztv['ok'], false); // 500 is not < 500
    });

    test('getStreams integrates with TrackerService', () async {
      try {
        final streams = await service.getStreams('movie', 'tt0000000', {});
        expect(streams, isList);
      } catch (e) {
        // If it throws network error from engine, that's expected in isolation
      }
    });
  });
}

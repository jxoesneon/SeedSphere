import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mockito/mockito.dart';
import 'package:router/addon_service.dart';
import 'package:router/scraper_service.dart';
import 'package:router/db_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Fake Mock
class FakeScraperService extends Fake implements ScraperService {
  @override
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String id,
    Map<String, dynamic> settings, {
    String? userId,
  }) async {
    return []; // Default empty
  }

  @override
  Future<List<Map<String, dynamic>>> probeProviders() async {
    return [];
  }
}

class MockDbService extends Mock implements DbService {}

void main() {
  group('AddonService', () {
    late AddonService service;
    late FakeScraperService fakeScraper;
    late MockDbService mockDb;
    late MockClient mockClient;

    setUp(() {
      fakeScraper = FakeScraperService();
      mockDb = MockDbService();

      // Mock Client behavior
      mockClient = MockClient((request) async {
        if (request.url.path.contains('/top.json')) {
          return http.Response(
            jsonEncode({
              'metas': [
                {'name': 'Mock Movie', 'poster': 'url'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      service = AddonService(fakeScraper, mockDb, mockClient);
    });

    test('Manifest returns valid JSON', () async {
      final req = Request('GET', Uri.parse('http://localhost/manifest.json'));
      final resp = await service.router(req);
      expect(resp.statusCode, 200);
      final body = jsonDecode(await resp.readAsString());
      expect(body['id'], 'community.seedsphere');
      expect(body['resources'], contains('stream'));
    });

    test('Catalog proxy returns mock data', () async {
      final req = Request(
        'GET',
        Uri.parse('http://localhost/catalog/movie/top.json'),
      );
      final resp = await service.router(req);
      expect(resp.statusCode, 200);
      final body = jsonDecode(await resp.readAsString());
      expect(body['metas'], isNotEmpty);
      expect(body['metas'][0]['name'], 'Mock Movie');
    });

    test('Catalog fallback on error', () async {
      final failingClient = MockClient(
        (_) async => throw Exception('Network Error'),
      );
      service = AddonService(fakeScraper, mockDb, failingClient);

      final req = Request(
        'GET',
        Uri.parse('http://localhost/catalog/movie/top.json'),
      );
      final resp = await service.router(req);
      expect(resp.statusCode, 200);
      final body = jsonDecode(await resp.readAsString());
      expect(body['metas'], isEmpty);
    });

    test('Variant Manifest (Lite)', () async {
      final req = Request(
        'GET',
        Uri.parse('http://localhost/manifest.variant.lite/manifest.json'),
      );
      final resp = await service.router(req);
      expect(resp.statusCode, 200);
      final body = jsonDecode(await resp.readAsString());
      expect(body['id'], 'community.seedsphere.lite');
      expect(body['types'], isNot(contains('anime')));
    });

    test('Variant Stream handles scraper', () async {
      // Use Stub to return specific data
      final stubScraper = _StubScraperService([
        {'name': 'Mock Stream'},
      ]);
      service = AddonService(stubScraper, mockDb, mockClient);

      final req = Request(
        'GET',
        Uri.parse(
          'http://localhost/manifest.variant.lite/stream/movie/tt123.json',
        ),
      );
      final resp = await service.router(req);
      expect(resp.statusCode, 200);
      final body = jsonDecode(await resp.readAsString());
      expect(body['streams'][0]['name'], 'Mock Stream');
    });
  });
}

class _StubScraperService extends FakeScraperService {
  final List<Map<String, dynamic>> streams;
  _StubScraperService(this.streams);

  @override
  Future<List<Map<String, dynamic>>> getStreams(
    String type,
    String id,
    Map<String, dynamic> settings, {
    String? userId,
  }) async {
    return streams;
  }
}

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:router/addon_service.dart';
import 'package:router/db_service.dart';
import 'package:router/scraper_service.dart';
import 'package:shelf/shelf.dart';
import 'dart:convert';

@GenerateNiceMocks([MockSpec<DbService>(), MockSpec<ScraperService>()])
import 'addon_service_coverage_test.mocks.dart';

void main() {
  group('AddonService Full Coverage', () {
    late AddonService addonService;
    late MockDbService mockDb;
    late MockScraperService mockScrapers;

    setUp(() {
      mockDb = MockDbService();
      mockScrapers = MockScraperService();
      addonService = AddonService(mockScrapers, mockDb);
    });

    test('generateManifest includes user hints', () async {
      when(
        mockDb.getUser('u1'),
      ).thenReturn({'id': 'u1', 'settings_json': '{}'});
      final manifest = await addonService.generateManifest(
        'u1',
        baseUrl: 'http://base',
      );
      expect(manifest['name'], contains('SeedSphere'));
      expect(manifest['configurationURL'], contains('http://base/configure'));
    });

    test('public manifest route', () async {
      final req = Request('GET', Uri.parse('http://localhost/manifest.json'));
      final res = await addonService.router(req);
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString());
      expect(body['name'], 'SeedSphere');
    });

    test('user manifest route', () async {
      when(mockDb.getUser('u1')).thenReturn({
        'id': 'u1',
        'settings': {
          'dynamic_catalogs': ['sci-fi'],
        },
      });
      final req = Request(
        'GET',
        Uri.parse('http://localhost/u/u1/manifest.json'),
      );
      final res = await addonService.router(req);
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString());
      expect(body['catalogs'].any((c) => c['name'] == 'sci-fi (AI)'), isTrue);
    });
  });
}

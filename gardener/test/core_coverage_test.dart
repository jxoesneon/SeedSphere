import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/stremio_server.dart';
import 'package:gardener/core/config_manager.dart';
import 'test_setup.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('StremioServer Full Coverage', () {
    late StremioServer server;

    setUp(() async {
      await setupSeedSphereTest();
      server = StremioServer();
    });

    test('manifest handler returns valid map', () async {
      final manifest = await server.getManifest();
      expect(manifest['name'], contains('SeedSphere'));
      expect(manifest['id'], 'org.seedsphere.gardener');
    });

    test('getCatalog handles recent history', () async {
      final res = await server.getCatalog('movie', 'seedsphere.recent', {});
      expect(res['metas'], isList);
    });

    test('config manager properties', () async {
      final config = ConfigManager();
      config.autoProxy = false;
      expect(config.autoProxy, isFalse);
      
      config.sortBy = 'Seeds';
      expect(config.sortBy, 'Seeds');

      expect(config.activeProvidersCount, greaterThan(0));
    });
  });
}

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/health_service.dart';
import 'package:test/test.dart';

void main() {
  group('HealthService', () {
    test('checkHealthy HTTP success (HEAD)', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') return http.Response('', 200);
        return http.Response('', 405);
      });
      final service = HealthService(client: mockClient);

      expect(await service.checkHealthy('http://example.com'), isTrue);
    });

    test('checkHealthy HTTP fallback to GET', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') return http.Response('', 405);
        if (request.method == 'GET') return http.Response('body', 200);
        return http.Response('', 500);
      });
      final service = HealthService(client: mockClient);

      expect(await service.checkHealthy('http://example.com'), isTrue);
    });

    test('checkHealthy HTTP fails on 404/500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 404);
      });
      final service = HealthService(client: mockClient);

      expect(await service.checkHealthy('http://example.com'), isFalse);
    });

    test('checkHealthy uses cache', () async {
      int calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('', 200);
      });
      final service = HealthService(client: mockClient);

      await service.checkHealthy('http://example.com');
      await service.checkHealthy('http://example.com');

      expect(calls, 1);
    });

    test('Rejects Private IPs (SSRF)', () async {
      // Note: This relies on real DNS resolving 127.0.0.1 which usually works locally
      final service = HealthService();
      expect(await service.checkHealthy('http://127.0.0.1'), isFalse);
      expect(await service.checkHealthy('http://localhost'), isFalse);
    });
  });
}

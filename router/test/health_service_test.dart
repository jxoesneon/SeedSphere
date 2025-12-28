import 'package:test/test.dart';
import 'package:router/health_service.dart';

void main() {
  group('HealthService', () {
    late HealthService healthService;

    setUp(() {
      healthService = HealthService();
    });

    test('checkHealthy - HTTP 200', () async {
      // Note: In a real CI, we might mock http. Client
      // For now, testing 1:1 parity logic
      final isHealthy = await healthService.checkHealthy('https://google.com');
      expect(isHealthy, isTrue);
    });

    test('checkHealthy - Invalid URL', () async {
      final isHealthy = await healthService.checkHealthy(
        'http://non-existent-domain-123.com',
      );
      expect(isHealthy, isFalse);
    });

    test('checkHealthy - UDP DNS check', () async {
      // Testing basic DNS lookup parity
      final isHealthy = await healthService.checkHealthy(
        'udp://tracker.opentrackr.org:1337/announce',
      );
      expect(isHealthy, isTrue);
    });

    test('checkHealthy - SSRF Localhost Rejected', () async {
      final isHealthy = await healthService.checkHealthy(
        'http://127.0.0.1:8080',
      );
      expect(isHealthy, isFalse);
    });

    test('checkHealthy - SSRF Private IP Rejected', () async {
      final privateIps = [
        'http://192.168.1.1',
        'http://10.0.0.5:80',
        'http://172.16.0.1',
        'http://169.254.169.254', // Cloud metadata
        'http://[::1]', // IPv6 loopback
        'http://[fd00::1]', // IPv6 unique local
      ];

      for (final ip in privateIps) {
        final isHealthy = await healthService.checkHealthy(ip);
        expect(isHealthy, isFalse, reason: 'Should reject $ip');
      }
    });
  });
}

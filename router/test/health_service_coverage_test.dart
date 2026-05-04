import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:router/health_service.dart';
import 'dart:io';

@GenerateNiceMocks([MockSpec<http.Client>()])
import 'health_service_coverage_test.mocks.dart';

void main() {
  group('HealthService Deep Coverage', () {
    late HealthService healthService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      healthService = HealthService(client: mockClient);
    });

    test('checkHealthy UDP (DNS fallback)', () async {
      // urlStr with udp:// scheme
      final ok = await healthService.checkHealthy('udp://google.com:80');
      // Should return true if DNS resolves google.com
      expect(ok, isTrue);
    });

    test('checkHealthy HTTP fallback to GET', () async {
      when(mockClient.head(any)).thenThrow(Exception('HEAD failed'));
      when(mockClient.get(any)).thenAnswer((_) async => http.Response('', 200));
      
      final ok = await healthService.checkHealthy('http://example.com');
      expect(ok, isTrue);
    });

    test('checkUdpTracker timeout', () async {
      // This will actually try to bind a socket and send a packet.
      // Since it's a real IP, it might timeout or fail.
      final ok = await healthService.checkUdpTracker('udp://1.2.3.4:5678', timeout: Duration(milliseconds: 100));
      expect(ok, isFalse);
    });
  });
}

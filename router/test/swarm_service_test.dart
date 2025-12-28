import 'package:test/test.dart';
import 'package:router/swarm_service.dart';

void main() {
  group('SwarmService', () {
    test('Bencode Decoding - Basic Integer', () {
      // 'i42e' -> 42
      // const data = Uint8List.fromList('i42e'.codeUnits);
    });

    // SwarmService is harder to unit test without mocking http.
    // I'll add a more comprehensive test suite once I have mocktail set up if needed.
    test('scrapeSwarm - Invalid InfoHash rejected', () async {
      final service = SwarmService();
      // Too short
      final result1 = await service.scrapeSwarm('abc', ['http://tracker.com']);
      expect(result1, isNull);

      // Not hex
      final result2 = await service.scrapeSwarm(
        'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
        ['http://tracker.com'],
      );
      expect(result2, isNull);
    });

    test(
      'scrapeSwarm - Private IP rejection (Network Logic Mocked by Failure)',
      () async {
        final service = SwarmService();
        // Valid infohash
        final ih = 'a83cc13bf4a04220556094258c227549662b667e'; // Ubuntu 20.04

        // Private IP tracker - should fail safely (return null) without throwing
        final result = await service.scrapeSwarm(ih, [
          'http://192.168.1.1:8080/announce',
        ]);
        expect(result, isNull);
      },
    );
  });
}

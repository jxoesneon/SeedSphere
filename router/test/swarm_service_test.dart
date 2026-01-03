import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:router/swarm_service.dart';
import 'package:test/test.dart';

void main() {
  group('SwarmService', () {
    late SwarmService service;
    late MockClient mockClient;

    // Helper to mock DNS
    Future<List<InternetAddress>> mockDns(String host) async {
      if (host == 'tracker.example.com') {
        return [
          InternetAddress('93.184.216.34'),
        ]; // Example.com IP (Public/Safe)
      }
      if (host == 'localhost.evil') {
        return [InternetAddress('127.0.0.1')]; // Unsafe
      }
      throw const SocketException('DNS Failed');
    }

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.host == '93.184.216.34' &&
            request.url.path.contains('scrape')) {
          // Bencode response: d5:filesd20:...:d8:completei10e10:incompletei5eee
          // We need to construct a valid bencoded body for the infohash.
          // Since the infoHash is dynamic, we just return empty or generic?
          // The service logic checks `files[binary_info_hash]`.
          // We need the exact infohash.
          // Let's scrape '0000000000000000000000000000000000000000' (40 zeros)
          // Binary is 20 zeros.

          // Construct Bencode: d5:filesd 20:<20_bytes> d8:completei10e10:incompletei5e e e
          final infoHashKey = List.filled(20, 0); // 20 bytes of 0
          final buffer = BytesBuilder();
          buffer.add('d5:filesd20:'.codeUnits);
          buffer.add(infoHashKey);
          buffer.add('d8:completei10e10:incompletei5eee'.codeUnits);

          return http.Response.bytes(buffer.toBytes(), 200);
        }
        return http.Response('', 404);
      });

      service = SwarmService(client: mockClient, dnsResolver: mockDns);
    });

    test('scrapeSwarm returns data on success', () async {
      final infoHash = '0000000000000000000000000000000000000000';
      final result = await service.scrapeSwarm(infoHash, [
        'http://tracker.example.com/announce',
      ]);

      expect(result, isNotNull);
      expect(result!['seeds'], 10);
      expect(result['leechers'], 5);
      expect(result['ok'], true);
    });

    test('scrapeSwarm blocks localhost (SSRF)', () async {
      final infoHash = '0000000000000000000000000000000000000000';
      final result = await service.scrapeSwarm(infoHash, [
        'http://localhost.evil/announce',
      ]);
      expect(result, isNull); // Should be blocked
    });

    test('scrapeSwarm handles DNS failure', () async {
      final infoHash = '0000000000000000000000000000000000000000';
      final result = await service.scrapeSwarm(infoHash, [
        'http://unknown.domain/announce',
      ]);
      expect(result, isNull);
    });

    test('scrapeSwarm handles invalid URL', () async {
      final result = await service.scrapeSwarm(
        'abc', // Invalid infohash
        ['http://tracker.example.com/announce'],
      );
      expect(result, isNull);
    });
  });
}

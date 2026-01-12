import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/premiumize_provider.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late PremiumizeProvider provider;

  setUp(() {
    mockClient = MockHttpClient();
    provider = PremiumizeProvider('test_key', client: mockClient);
    registerFallbackValue(Uri());
  });

  group('PremiumizeProvider', () {
    test('getUser returns data', () async {
      final jsonResponse = {'status': 'success', 'customer_id': '123'};
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getUser();
      expect(result['customer_id'], '123');
    });

    test('addMagnet returns ID', () async {
      final jsonResponse = {'status': 'success', 'id': 'trans123'};

      when(
        () => mockClient.post(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.addMagnet('magnet:?xt=urn:btih:123');
      expect(result['id'], 'trans123');
    });

    test('checkAvailability handles successful response', () async {
      final jsonResponse = {
        'status': 'success',
        'response': [true, false],
      };

      // We manually construct URI and check manual query params in implementation,
      // but verify internal logic uses _client.get(uri).
      // The implementation constructs a Uri with 'items[]' repeated.

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.checkAvailability(['hash1', 'hash2']);
      expect(result['hash1'], true);
      expect(result['hash2'], false);
    });

    test('getTorrentInfo handles finished/downloaded status', () async {
      final listResponse = {
        'status': 'success',
        'transfers': [
          {
            'id': '123',
            'status': 'finished',
            'folder_id': 'f1',
            'progress': 1.0,
          },
        ],
      };

      final folderResponse = {
        'status': 'success',
        'content': [
          {
            'id': 'file1',
            'name': 'movie.mkv',
            'size': 100,
            'link': 'http://dl.com/movie.mkv',
          },
        ],
      };

      // Mock list call
      when(
        () => mockClient.get(
          any(that: predicate((Uri u) => u.path.contains('transfer/list'))),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(listResponse), 200));

      // Mock folder list call
      when(
        () => mockClient.get(
          any(that: predicate((Uri u) => u.path.contains('folder/list'))),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(folderResponse), 200));

      final result = await provider.getTorrentInfo('123');
      expect(result['status'], 'downloaded');
      expect(result['files'].length, 1);
      final file = result['files'][0];
      expect(file['link'], 'http://dl.com/movie.mkv');
    });
  });
}

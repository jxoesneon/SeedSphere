import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/all_debrid_provider.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late AllDebridProvider provider;

  setUp(() {
    mockClient = MockHttpClient();
    provider = AllDebridProvider('test_key', client: mockClient);
    registerFallbackValue(Uri());
  });

  group('AllDebridProvider', () {
    test('getUser returns data on success', () async {
      final jsonResponse = {
        'status': 'success',
        'data': {'user': 'test_user'},
      };
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getUser();
      expect(result['user'], 'test_user');
    });

    test('addMagnet returns ID and Hash', () async {
      final jsonResponse = {
        'status': 'success',
        'data': {
          'magnets': [
            {'id': 123, 'hash': 'abc', 'error': null},
          ],
        },
      };

      // AllDebrid uses POST for upload
      when(
        () => mockClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.addMagnet('magnet:?xt=urn:btih:abc');
      expect(result['id'], '123');
      expect(result['hash'], 'abc');
    });

    test('addMagnet throws on API error', () async {
      final jsonResponse = {
        'status': 'success',
        'data': {
          'magnets': [
            {
              'id': 123,
              'error': {'code': 'Error', 'message': 'Invalid Magnet'},
            },
          ],
        },
      };

      when(
        () => mockClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      expect(
        () => provider.addMagnet('magnet:?xt=urn:btih:fail'),
        throwsException,
      );
    });

    test('checkAvailability returns correct status', () async {
      final jsonResponse = {
        'status': 'success',
        'data': {
          'magnets': [
            {'magnet': 'hash1', 'instant': true},
            {'magnet': 'hash2', 'instant': false},
          ],
        },
      };

      when(
        () => mockClient.post(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.checkAvailability(['hash1', 'hash2']);
      expect(result['hash1'], true);
      expect(result['hash2'], false);
    });

    test('getTorrentInfo maps status correctly', () async {
      // Status 4 = Ready -> 'downloaded'
      final jsonResponse = {
        'status': 'success',
        'data': {
          'magnets': {
            '123': {'statusCode': 4, 'downloaded': 100, 'links': []},
          },
        },
      };

      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getTorrentInfo('123');
      expect(result['status'], 'downloaded');
    });
  });
}

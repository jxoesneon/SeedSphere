import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/orion_provider.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late OrionProvider provider;

  setUp(() {
    mockClient = MockHttpClient();
    provider = OrionProvider('test_token', client: mockClient);
    registerFallbackValue(Uri());
  });

  group('OrionProvider', () {
    test('getUser returns user data', () async {
      final jsonResponse = {
        'result': {'status': 'success'},
        'data': {'user': 'orion_user'},
      };

      when(
        () => mockClient.get(
          any(
            that: predicate(
              (Uri u) => u.queryParameters['action'] == 'account',
            ),
          ),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getUser();
      expect(result['user'], 'orion_user');
    });

    test('addMagnet returns torrent ID', () async {
      final jsonResponse = {
        'result': {'status': 'success'},
        'data': {'id': 'orion_id', 'hash': 'abc'},
      };

      when(
        () => mockClient.get(
          any(
            that: predicate(
              (Uri u) => u.queryParameters['action'] == 'addtorrent',
            ),
          ),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.addMagnet('magnet:?xt=urn:btih:123');
      expect(result['id'], 'orion_id');
    });

    test('getTorrentInfo parses finished status', () async {
      final jsonResponse = {
        'result': {'status': 'success'},
        'data': {
          'status': 'finished',
          'progress': 100,
          'files': [
            {'link': 'http://dl.com/movie.mkv', 'path': 'movie.mkv'},
          ],
        },
      };

      when(
        () => mockClient.get(
          any(
            that: predicate(
              (Uri u) => u.queryParameters['action'] == 'torrentinfo',
            ),
          ),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getTorrentInfo('123');
      expect(result['status'], 'downloaded');
      expect(result['links'].length, 1);
    });

    test('checkAvailability returns false on error/missing', () async {
      when(
        () => mockClient.get(
          any(
            that: predicate((Uri u) => u.queryParameters['action'] == 'stream'),
          ),
        ),
      ).thenAnswer(
        (_) async => http.Response('{"result":{"status":"error"}}', 200),
      );

      final result = await provider.checkAvailability(['hash']);
      expect(result['hash'], isFalse);
    });
  });
}

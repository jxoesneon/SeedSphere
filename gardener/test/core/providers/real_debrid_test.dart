import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/real_debrid_provider.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late RealDebridProvider provider;

  setUp(() {
    mockClient = MockHttpClient();
    provider = RealDebridProvider('test_token', client: mockClient);
    registerFallbackValue(Uri());
  });

  group('RealDebridProvider', () {
    test('getUser returns user data', () async {
      final jsonResponse = {'id': 123, 'username': 'test'};
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getUser();
      expect(result['username'], 'test');
    });

    test('addMagnet returns parsed ID', () async {
      final jsonResponse = {'id': 'rd_id', 'uri': 'magnet...'};
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 201));

      final result = await provider.addMagnet('magnet:?xt=urn:btih:123');
      expect(result['id'], 'rd_id');
    });

    test('getTorrentInfo handles files and status', () async {
      final jsonResponse = {
        'id': 'rd_id',
        'status': 'downloaded',
        'progress': 100,
        'links': ['link1'],
        'files': [
          {'id': 1, 'path': '/movie.mkv', 'bytes': 1000, 'selected': 1},
        ],
      };
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.getTorrentInfo('rd_id');
      expect(result['status'], 'downloaded');
      expect(result['files'][0]['path'], '/movie.mkv');
    });

    test('selectFiles posts correct body', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 204));

      await provider.selectFiles('id', '1');
      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: {'files': '1'},
        ),
      ).called(1);
    });

    test('unrestrictLink returns download link', () async {
      final jsonResponse = {'download': 'http://real.debrid/file'};
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.unrestrictLink('orig_link');
      expect(result['download'], 'http://real.debrid/file');
    });

    test('checkAvailability handles dictionary response', () async {
      final jsonResponse = {
        'hash1': {
          'rd': [
            {
              'files': {
                '1': {'filename': 'movie'},
              },
              'filesize': 100,
            },
          ],
        },
        'hash2': {'rd': []}, // Not cached
      };

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(jsonResponse), 200));

      final result = await provider.checkAvailability(['hash1', 'hash2']);
      expect(result['hash1'], true);
      expect(result['hash2'], false);
    });
  });
}

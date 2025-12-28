import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/debrid_client.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/stream_resolver.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

class MockLocalKMS extends Mock implements LocalKMS {}

class MockDebridClient extends Mock implements DebridClient {}

void main() {
  late MockHttpClient mockClient;
  late MockLocalKMS mockKMS;

  setUp(() {
    mockClient = MockHttpClient();
    mockKMS = MockLocalKMS();
    registerFallbackValue(Uri());
  });

  group('DebridClient', () {
    test('addMagnet posts to correct endpoint', () async {
      when(() => mockKMS.getDebridKey()).thenAnswer((_) async => 'key123');
      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response(jsonEncode({'id': 'magnet123'}), 201));

      final client = DebridClient(kms: mockKMS, client: mockClient);
      final result = await client.addMagnet('magnet:?xt=urn:btih:hash');

      expect(result['id'], 'magnet123');
      verify(() => mockClient.post(
            Uri.parse(
                'https://api.real-debrid.com/rest/1.0/torrents/addMagnet'),
            headers: {'Authorization': 'Bearer key123'},
            body: {'magnet': 'magnet:?xt=urn:btih:hash'},
          )).called(1);
    });

    test('Throws if no key', () async {
      when(() => mockKMS.getDebridKey()).thenAnswer((_) async => null);
      final client = DebridClient(kms: mockKMS, client: mockClient);
      expect(() => client.addMagnet('hash'), throwsA(isA<Exception>()));
    });
    test('getUser calls correct endpoint', () async {
      when(() => mockKMS.getDebridKey()).thenAnswer((_) async => 'key123');
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode({'username': 'Eduardo'}), 200));

      final client = DebridClient(kms: mockKMS, client: mockClient);
      final result = await client.getUser();

      expect(result['username'], 'Eduardo');
      verify(() => mockClient.get(
            Uri.parse('https://api.real-debrid.com/rest/1.0/user'),
            headers: {'Authorization': 'Bearer key123'},
          )).called(1);
    });

    test('unrestrictLink posts correctly', () async {
      when(() => mockKMS.getDebridKey()).thenAnswer((_) async => 'key123');
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async =>
              http.Response(jsonEncode({'download': 'http://link'}), 200));

      final client = DebridClient(kms: mockKMS, client: mockClient);
      final result = await client.unrestrictLink('http://source');

      expect(result['download'], 'http://link');
    });

    test('Throws on API error', () async {
      when(() => mockKMS.getDebridKey()).thenAnswer((_) async => 'key123');
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Error', 403));

      final client = DebridClient(kms: mockKMS, client: mockClient);
      expect(() => client.getUser(), throwsException);
    });
  });

  group('StreamResolver', () {
    test('Resolves magnet to stream link', () async {
      final mockDebrid = MockDebridClient();
      when(() => mockDebrid.addMagnet(any()))
          .thenAnswer((_) async => {'id': 'stream123'});

      final resolver = StreamResolver(debrid: mockDebrid);
      final url = await resolver.resolveStream('hash123');

      expect(url, 'https://real-debrid.com/streaming/stream123');
      verify(() => mockDebrid.addMagnet('magnet:?xt=urn:btih:hash123'))
          .called(1);
    });

    test('Returns null on error', () async {
      final mockDebrid = MockDebridClient();
      when(() => mockDebrid.addMagnet(any())).thenThrow(Exception('Fail'));

      final resolver = StreamResolver(debrid: mockDebrid);
      expect(await resolver.resolveStream('hash'), isNull);
    });
  });
}

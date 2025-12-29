import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/pairing_manager.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockP2PManager extends Mock implements P2PManager {}

class MockSecurityManager extends Mock implements SecurityManager {}

class MockClient extends Mock implements http.Client {}

class FakeP2PCommand extends Fake implements P2PCommand {}

void main() {
  late PairingManager manager;
  late MockP2PManager mockP2P;
  late MockSecurityManager mockSecurity;
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeP2PCommand());
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockP2P = MockP2PManager();
    mockSecurity = MockSecurityManager();
    mockClient = MockClient();
    manager = PairingManager(
      mockP2P,
      security: mockSecurity,
      client: mockClient,
    );
  });

  group('PairingManager', () {
    test('generatePairingPayload creates valid base64 encoded json', () {
      final payload = manager.generatePairingPayload('key123', 'gardener1');
      final decodedJson = utf8.decode(base64Decode(payload));
      final map = jsonDecode(decodedJson);

      expect(map['gardenerId'], 'gardener1');
      expect(map['debridKey'], 'key123');
      expect(map['timestamp'], isA<int>());
    });

    test('startPairingListener sends boost command', () {
      // Stub sendCommand as it returns void
      // when(() => mockP2P.sendCommand(any())).thenReturn(null);

      manager.startPairingListener('xyz');

      final captured = verify(() => mockP2P.sendCommand(captureAny())).captured;
      final cmd = captured.first as P2PCommand;
      final data = cmd.data as Map<String, dynamic>;

      expect(cmd.type, P2PCommandType.boost);
      expect(cmd.imdbId, 'pairing:xyz');
      expect(data['status'], 'waiting');
    });

    test('requestLinkingToken returns token on success', () async {
      when(() => mockP2P.gardenerId).thenReturn('g1');
      when(() => mockClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              ))
          .thenAnswer(
              (_) async => http.Response('{"ok":true,"token":"tok123"}', 200));

      final token = await manager.requestLinkingToken();
      expect(token, 'tok123');
    });

    test('completeLinkingWithToken stores secret on success', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer(
              (_) async => http.Response('{"ok":true,"secret":"sec123"}', 200));
      when(() => mockSecurity.setSharedSecret('sec123'))
          .thenAnswer((_) async {});

      final result = await manager.completeLinkingWithToken('tok123');
      expect(result, true);
      verify(() => mockSecurity.setSharedSecret('sec123')).called(1);
    });
  });
}

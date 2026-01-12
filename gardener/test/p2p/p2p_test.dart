import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/core/pairing_manager.dart';
import 'dart:convert';

class MockP2PManager extends Mock implements P2PManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockP2PManager mockP2P;

  setUp(() {
    mockP2P = MockP2PManager();
    registerFallbackValue(P2PCommand(type: P2PCommandType.status, imdbId: ''));
  });

  group('P2PProtocol', () {
    test('Topic generation is consistent', () {
      expect(P2PProtocol.getTopic('tt1234567'), 'ss/v1/meta/tt1234567');
    });

    test('DHT Key hashing is deterministic', () {
      final key1 = P2PProtocol.getDhtKey('tt1234567');
      final key2 = P2PProtocol.getDhtKey('tt1234567');
      expect(key1, key2);
    });

    test('Command serialization', () {
      final cmd = P2PCommand(
        type: P2PCommandType.search,
        imdbId: 'tt1234567',
        data: {'quality': '1080p'},
      );

      final json = cmd.toJson();
      final decoded = P2PCommand.fromJson(json);

      expect(decoded.type, P2PCommandType.search);
      expect(decoded.imdbId, 'tt1234567');
      expect(decoded.data?['quality'], '1080p');
    });
  });

  group('PairingManager', () {
    test('Generates valid pairing payload', () {
      final manager = PairingManager(mockP2P);
      final payload = manager.generatePairingPayload('key123', 'gardener-abc');

      final decoded = jsonDecode(utf8.decode(base64Decode(payload)));
      expect(decoded['gardenerId'], 'gardener-abc');
      expect(decoded['debridKey'], 'key123');
    });

    test('Listener subscribes to boost topic', () {
      final manager = PairingManager(mockP2P);
      manager.startPairingListener('pair-123');

      final verifyCapture = verify(() => mockP2P.sendCommand(captureAny()));
      verifyCapture.called(1);

      final cmd = verifyCapture.captured.first as P2PCommand;
      expect(cmd.type, P2PCommandType.boost);
      expect(cmd.imdbId, 'pairing:pair-123');
    });
  });
}

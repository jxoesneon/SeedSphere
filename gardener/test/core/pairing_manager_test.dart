import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gardener/core/pairing_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:http/http.dart' as http;

class MockP2PManager extends Mock implements P2PManager {}

class MockLocalKMS extends Mock implements LocalKMS {}

class MockSecurityManager extends Mock implements SecurityManager {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockP2PManager mockP2P;
  late MockLocalKMS mockKMS;
  late PairingManager manager;

  setUp(() {
    mockP2P = MockP2PManager();
    mockKMS = MockLocalKMS();
    manager = PairingManager(mockP2P, kms: mockKMS);
  });

  group('PairingManager', () {
    test('generatePairingPayload creates valid base64 json', () {
      final payload = manager.generatePairingPayload('key123', 'gardener1');
      final decoded = jsonDecode(utf8.decode(base64Decode(payload)));

      expect(decoded['gardenerId'], 'gardener1');
      expect(decoded['debridKey'], 'key123');
      expect(decoded.containsKey('timestamp'), isTrue);
    });

    test('completePairing stores key for valid payload', () async {
      when(() => mockKMS.storeDebridKey(any())).thenAnswer((_) async {});

      // Create valid fresh payload
      final validMap = {
        'gardenerId': 'g1',
        'debridKey': 'k1',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final payload = base64Encode(utf8.encode(jsonEncode(validMap)));

      await manager.completePairing(payload);

      verify(() => mockKMS.storeDebridKey('k1')).called(1);
    });

    test('completePairing rejects expired payload', () async {
      // Create expired payload (10 mins ago)
      final expiredMap = {
        'gardenerId': 'g1',
        'debridKey': 'k1',
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      };
      final payload = base64Encode(utf8.encode(jsonEncode(expiredMap)));

      await manager.completePairing(payload);

      verifyNever(() => mockKMS.storeDebridKey(any()));
    });

    test('completePairing rejects invalid structure', () async {
      await manager.completePairing('invalid_base64');
      verifyNever(() => mockKMS.storeDebridKey(any()));

      final emptyJson = base64Encode(utf8.encode('{}'));
      await manager.completePairing(emptyJson);
      verifyNever(() => mockKMS.storeDebridKey(any()));
    });
  });
}

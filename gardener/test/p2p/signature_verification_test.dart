import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:convert';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late SecurityManager security;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    // Mock storage behavior for keys
    final keyPair = ed.generateKey();
    when(
      () => mockStorage.read(key: 'ss_private_key'),
    ).thenAnswer((_) async => base64Encode(keyPair.privateKey.bytes));
    when(
      () => mockStorage.read(key: 'ss_public_key'),
    ).thenAnswer((_) async => base64Encode(keyPair.publicKey.bytes));

    security = SecurityManager(storage: mockStorage);
  });

  test('P2PCommand Signing Flow', () async {
    // 1. Create Command
    final cmd = P2PCommand(
      type: P2PCommandType.search,
      imdbId: 'tt1234567',
      data: {'timestamp': DateTime.now().toIso8601String()},
    );

    // 2. Serialize
    final jsonCmd = cmd.toJson();
    final payloadString = jsonEncode(jsonCmd);

    // 3. Sign
    final signature = await security.signMessage(payloadString);
    expect(signature, isNotEmpty);

    // 4. Verify
    final keyPair = await security.getKeyPair();
    final pubKey = base64Encode(keyPair.publicKey.bytes);

    final isValid = security.verifySignature(payloadString, signature, pubKey);
    expect(isValid, isTrue);
  });
}

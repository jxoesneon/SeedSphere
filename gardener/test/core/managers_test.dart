import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/core/identity_manager.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/core/reputation_manager.dart';
import 'package:gardener/core/local_kms.dart';
import 'dart:convert';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
  });

  group('IdentityManager', () {
    test('Generates new IDs if storage is empty', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'))).thenAnswer((_) async => {});

      final manager = IdentityManager(storage: mockStorage);
      final peerId = await manager.getPeerId();
      final gardenerId = await manager.getGardenerId();

      expect(peerId, isNotEmpty);
      expect(gardenerId, startsWith('gardener-'));
      // Verify storage writes occurred
      verify(() =>
              mockStorage.write(key: 'ss_peer_id', value: any(named: 'value')))
          .called(1);
    });

    test('Returns existing IDs from storage', () async {
      when(() => mockStorage.read(key: 'ss_peer_id'))
          .thenAnswer((_) async => 'existing-peer');
      when(() => mockStorage.read(key: 'ss_gardener_id'))
          .thenAnswer((_) async => 'existing-gardener');

      final manager = IdentityManager(storage: mockStorage);

      expect(await manager.getPeerId(), 'existing-peer');
      expect(await manager.getGardenerId(), 'existing-gardener');
    });
  });

  group('SecurityManager', () {
    test('Sign and Verify Message', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'))).thenAnswer((_) async => {});

      final manager = SecurityManager(storage: mockStorage);
      final keyPair = await manager.getKeyPair();

      // Should write private and public keys
      verify(() => mockStorage.write(
          key: any(named: 'key'), value: any(named: 'value'))).called(2);
      const message = 'Hello Swarm';

      final signature = await manager.signMessage(message);
      final publicKey = base64Encode(keyPair.publicKey.bytes);

      final isValid = manager.verifySignature(message, signature, publicKey);
      expect(isValid, true);
    });
  });

  group('ReputationManager', () {
    test('Blacklists peer after threshold', () {
      final manager = ReputationManager();
      manager.adjustScore('peer-bad', -60);
      expect(manager.isBlacklisted('peer-bad'), true);
      expect(manager.getScore('peer-bad'), -60);
    });

    test('Keeps peer valid above threshold', () {
      final manager = ReputationManager();
      manager.adjustScore('peer-good', -10);
      expect(manager.isBlacklisted('peer-good'), false);
    });
  });

  group('LocalKMS', () {
    test('Stores and Retrieves Keys', () async {
      when(() => mockStorage.read(key: 'ss_ai_kms_key'))
          .thenAnswer((_) async => 'sk-12345');
      when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'))).thenAnswer((_) async => {});

      final kms = LocalKMS(storage: mockStorage);
      await kms.storeAIKey('sk-12345');

      expect(await kms.getAIKey(), 'sk-12345');
      verify(() => mockStorage.write(key: 'ss_ai_kms_key', value: 'sk-12345'))
          .called(1);
    });
  });
}

import 'package:test/test.dart';
import 'package:router/crypto_helper.dart';
import 'dart:convert';

void main() {
  group('CryptoHelper', () {
    test('Encrypt and Decrypt - Success', () async {
      final plain = 'Hello SeedSphere';
      final key = 'super-secret-key-123';

      final encrypted = await CryptoHelper.encrypt(plain, key);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(plain));

      final decrypted = await CryptoHelper.decrypt(encrypted, key);
      expect(decrypted, equals(plain));
    });

    test('Encryption should use random salts (Probabilistic)', () async {
      final plain = 'Same Text';
      final key = 'key';

      final e1 = await CryptoHelper.encrypt(plain, key);
      final e2 = await CryptoHelper.encrypt(plain, key);

      // Since salt and IV are random, outputs MUST be different
      expect(e1, isNot(equals(e2)));

      // But both should decrypt to same
      expect(await CryptoHelper.decrypt(e1, key), equals(plain));
      expect(await CryptoHelper.decrypt(e2, key), equals(plain));
    });

    test('Decrypt with wrong key fails', () async {
      final plain = 'Secret';
      final key = 'key1';
      final wrongKey = 'key2';

      final encrypted = await CryptoHelper.encrypt(plain, key);

      expect(
        () => CryptoHelper.decrypt(encrypted, wrongKey),
        throwsA(isA<Exception>()),
      );
    });

    test('Decrypt garbage fails', () async {
      final garbage = base64Encode(utf8.encode('NotEncryptedData'));
      expect(
        () => CryptoHelper.decrypt(garbage, 'key'),
        throwsA(isA<Exception>()),
      );
    });

    test('Empty string handling', () async {
      expect(await CryptoHelper.encrypt('', 'key'), equals(''));
      expect(await CryptoHelper.decrypt('', 'key'), equals(''));
    });
  }, timeout: const Timeout(Duration(seconds: 90)));
}

import 'package:test/test.dart';
import 'package:router/crypto_helper.dart';
import 'dart:convert';

void main() {
  group('CryptoHelper', () {
    test('Encrypt and Decrypt - Success', () {
      final plain = 'Hello SeedSphere';
      final key = 'super-secret-key-123';

      final encrypted = CryptoHelper.encrypt(plain, key);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(plain));

      final decrypted = CryptoHelper.decrypt(encrypted, key);
      expect(decrypted, equals(plain));
    });

    test('Encryption should use random salts (Probabilistic)', () {
      final plain = 'Same Text';
      final key = 'key';

      final e1 = CryptoHelper.encrypt(plain, key);
      final e2 = CryptoHelper.encrypt(plain, key);

      // Since salt and IV are random, outputs MUST be different
      expect(e1, isNot(equals(e2)));

      // But both should decrypt to same
      expect(CryptoHelper.decrypt(e1, key), equals(plain));
      expect(CryptoHelper.decrypt(e2, key), equals(plain));
    });

    test('Decrypt with wrong key fails', () {
      final plain = 'Secret';
      final key = 'key1';
      final wrongKey = 'key2';

      final encrypted = CryptoHelper.encrypt(plain, key);

      expect(() => CryptoHelper.decrypt(encrypted, wrongKey), throwsException);
    });

    test('Decrypt garbage fails', () {
      final garbage = base64Encode(utf8.encode('NotEncryptedData'));
      expect(() => CryptoHelper.decrypt(garbage, 'key'), throwsException);
    });

    test('Empty string handling', () {
      expect(CryptoHelper.encrypt('', 'key'), equals(''));
      expect(CryptoHelper.decrypt('', 'key'), equals(''));
    });
  });
}

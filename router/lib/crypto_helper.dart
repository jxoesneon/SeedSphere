import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:pointycastle/export.dart';

/// Utility class for cryptographic operations (AES-GCM encryption/decryption).
class CryptoHelper {
  static final _secureRandom = _getSecureRandom();
  static const int _saltLength = 16; // 128-bit salt
  static const int _ivLength = 12; // 96-bit IV
  static const int _iterations =
      600000; // OWASP recommendation for PBKDF2-HMAC-SHA256
  static const int _keyLength = 32; // 256-bit key
  static final Logger _logger = Logger('CryptoHelper');

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  static Uint8List _generateBytes(int length) {
    return _secureRandom.nextBytes(length);
  }

  /// Encrypts [plaintext] using AES-GCM with the provided [secretKey].
  ///
  /// Returns a base64 encoded string containing: `Salt (16) + IV (12) + CipherText + AuthTag`.
  /// Uses PBKDF2-HMAC-SHA256 for key derivation.
  static String encrypt(String plaintext, String secretKey) {
    if (plaintext.isEmpty) return '';
    try {
      final salt = _generateBytes(_saltLength);
      final keyBytes = _deriveKey(secretKey, salt);
      final iv = _generateBytes(_ivLength);

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          true, // encrypt
          AEADParameters(
            KeyParameter(keyBytes),
            128, // mac size (bits)
            iv,
            Uint8List(0), // associated data
          ),
        );

      final input = utf8.encode(plaintext);
      final output = cipher.process(Uint8List.fromList(input));

      // Combine Salt + IV + Output
      final combined = Uint8List(_saltLength + _ivLength + output.length);
      combined.setAll(0, salt);
      combined.setAll(_saltLength, iv);
      combined.setAll(_saltLength + _ivLength, output);

      return base64Encode(combined);
    } catch (e) {
      _logger.warning('Encryption error: $e');
      throw Exception('Encryption failed');
    }
  }

  /// Decrypts a base64 encoded [ciphertext] using AES-GCM and [secretKey].
  ///
  /// Expects the format: `Salt (16) + IV (12) + CipherText + AuthTag`.
  /// Throws an [Exception] if decryption fails or data is corrupt.
  static String decrypt(String ciphertext, String secretKey) {
    if (ciphertext.isEmpty) return '';
    try {
      final combined = base64Decode(ciphertext);

      // Validation
      if (combined.length < _saltLength + _ivLength) {
        throw Exception('Invalid ciphertext length');
      }

      // Extract parts
      final salt = combined.sublist(0, _saltLength);
      final iv = combined.sublist(_saltLength, _saltLength + _ivLength);
      final cipherBytes = combined.sublist(_saltLength + _ivLength);

      final keyBytes = _deriveKey(secretKey, salt);

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false, // decrypt
          AEADParameters(
            KeyParameter(keyBytes),
            128, // mac size
            iv,
            Uint8List(0),
          ),
        );

      final output = cipher.process(cipherBytes);
      return utf8.decode(output);
    } catch (e) {
      // Fallback for old "Fixed Salt" format?
      // The old format was base64(IV + Cipher). IV=12 bytes.
      // New format base64(Salt + IV + Cipher). Salt=16.
      // If we fail, we could TRY to decrypt with old logic IF we wanted backward compat.
      // But user said "proceed with all" implies fix. Breaking change IS the fix usually.
      // I will assume breaking change is acceptable or I'd need to try-catch-fallback.
      // Let's stick to secure only.
      _logger.warning('Decryption error: $e');
      throw Exception('Decryption failed (Invalid Key or Corrupt Data)');
    }
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    if (password.isEmpty) throw ArgumentError('Password cannot be empty');

    final pbkdf2 = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(salt, _iterations, _keyLength);

    pbkdf2.init(params);
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }
}

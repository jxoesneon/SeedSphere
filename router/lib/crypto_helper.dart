import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:cryptography/cryptography.dart';

/// Utility class for cryptographic operations (XChaCha20-Poly1305 encryption/decryption).
/// Aligned with SECURITY.md SEC-008.
class CryptoHelper {
  static const int _saltLength = 16;
  static const int _iterations = 600000;
  static const int _keyLength = 32;
  static final Logger _logger = Logger('CryptoHelper');
  static final _algorithm = Xchacha20.poly1305Aead();

  static Random _getSecureRandom() {
    return Random.secure();
  }

  static Uint8List _generateBytes(int length) {
    final random = _getSecureRandom();
    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256)),
    );
  }

  /// Encrypts [plaintext] using XChaCha20-Poly1305 with the provided [secretKey].
  ///
  /// Returns a base64 encoded string containing: `Salt (16) + Nonce (24) + CipherText + MAC (16)`.
  /// Uses PBKDF2-HMAC-SHA256 for key derivation.
  static Future<String> encrypt(String plaintext, String secretKey) async {
    if (plaintext.isEmpty) return '';
    try {
      final salt = _generateBytes(_saltLength);
      final derivedKeyBytes = await _deriveKey(secretKey, salt);

      final secretKeyObj = await _algorithm.newSecretKeyFromBytes(
        derivedKeyBytes,
      );
      final nonce = _algorithm.newNonce();

      final secretBox = await _algorithm.encrypt(
        utf8.encode(plaintext),
        secretKey: secretKeyObj,
        nonce: nonce,
      );

      final combined = Uint8List(
        _saltLength +
            secretBox.nonce.length +
            secretBox.cipherText.length +
            secretBox.mac.bytes.length,
      );

      int offset = 0;
      combined.setAll(offset, salt);
      offset += salt.length;
      combined.setAll(offset, secretBox.nonce);
      offset += secretBox.nonce.length;
      combined.setAll(offset, secretBox.cipherText);
      offset += secretBox.cipherText.length;
      combined.setAll(offset, secretBox.mac.bytes);

      return base64Encode(combined);
    } catch (e) {
      _logger.warning('Encryption error: $e');
      throw Exception('Encryption failed');
    }
  }

  /// Decrypts a base64 encoded [ciphertext] using XChaCha20-Poly1305 and [secretKey].
  ///
  /// Expects the format: `Salt (16) + Nonce (24) + CipherText + MAC (16)`.
  static Future<String> decrypt(String ciphertext, String secretKey) async {
    if (ciphertext.isEmpty) return '';
    try {
      final combined = base64Decode(ciphertext);
      const nonceLength = 24;
      const macLength = 16;

      if (combined.length < _saltLength + nonceLength + macLength) {
        throw Exception('Invalid ciphertext length');
      }

      int offset = 0;
      final salt = combined.sublist(offset, offset + _saltLength);
      offset += _saltLength;
      final nonce = combined.sublist(offset, offset + nonceLength);
      offset += nonceLength;
      final cipherText = combined.sublist(offset, combined.length - macLength);
      final macBytes = combined.sublist(combined.length - macLength);

      final derivedKeyBytes = await _deriveKey(secretKey, salt);
      final secretKeyObj = await _algorithm.newSecretKeyFromBytes(
        derivedKeyBytes,
      );

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      final clearText = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKeyObj,
      );

      return utf8.decode(clearText);
    } catch (e) {
      _logger.warning('Decryption error: $e');
      throw Exception('Decryption failed (Invalid Key or Corrupt Data)');
    }
  }

  static Future<Uint8List> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: _keyLength * 8,
    );
    final secretKey = SecretKey(utf8.encode(password));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    final bytes = await derivedKey.extractBytes();
    return Uint8List.fromList(bytes);
  }
}

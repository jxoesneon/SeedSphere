import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Cryptographic security manager for peer identity and message signing.
///
/// Manages Ed25519 key pairs for secure peer-to-peer communication,
/// and HMAC-SHA256 for authenticated server communication (SeedSphere Router).
class SecurityManager {
  final FlutterSecureStorage _storage;
  static const _privateKeyKey = 'ss_private_key';
  static const _publicKeyKey = 'ss_public_key';
  static const _sharedSecretKey = 'ss_shared_secret';

  /// Cached key pair to avoid repeated secure storage reads.
  static ed.KeyPair? _cachedKeyPair;

  /// Creates a new [SecurityManager] instance.
  ///
  /// [storage] - Optional secure storage for testing. Defaults to [FlutterSecureStorage].
  SecurityManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Retrieves or generates an Ed25519 key pair.
  ///
  /// If no key pair exists, generates a new one and stores it securely.
  /// Subsequent calls return the cached key pair for performance.
  ///
  /// Returns the Ed25519 key pair containing both private and public keys.
  Future<ed.KeyPair> getKeyPair() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;

    final privHex = await _storage.read(key: _privateKeyKey);
    final pubHex = await _storage.read(key: _publicKeyKey);
    ed.KeyPair keyPair;

    if (privHex == null || pubHex == null) {
      // Generate new key pair if none exists
      keyPair = ed.generateKey();
      await _storage.write(
        key: _privateKeyKey,
        value: base64Encode(keyPair.privateKey.bytes),
      );
      await _storage.write(
        key: _publicKeyKey,
        value: base64Encode(keyPair.publicKey.bytes),
      );
    } else {
      // Reconstruct key pair from stored keys
      final privateBytes = base64Decode(privHex);
      final publicBytes = base64Decode(pubHex);
      final privateKey = ed.PrivateKey(privateBytes);
      final publicKey = ed.PublicKey(publicBytes);
      keyPair = ed.KeyPair(privateKey, publicKey);
    }

    _cachedKeyPair = keyPair;
    return keyPair;
  }

  /// Signs a message using the stored private key.
  ///
  /// [message] - The message string to sign.
  ///
  /// Returns a base64-encoded Ed25519 signature.
  ///
  /// Example:
  /// ```dart
  /// final signature = await security.signMessage('authenticate:user123');
  /// ```
  Future<String> signMessage(String message) async {
    final keyPair = await getKeyPair();
    final signature = ed.sign(keyPair.privateKey, utf8.encode(message));
    return base64Encode(signature);
  }

  /// Verifies an Ed25519 signature against a message and public key.
  ///
  /// [message] - The original message that was signed.
  /// [signatureBase64] - The base64-encoded signature to verify.
  /// [publicKeyBase64] - The base64-encoded public key of the signer.
  ///
  /// Returns `true` if the signature is valid, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final isValid = security.verifySignature(
  ///   'authenticate:user123',
  ///   receivedSignature,
  ///   peerPublicKey,
  /// );
  /// if (!isValid) throw Exception('Invalid signature');
  /// ```
  bool verifySignature(
      String message, String signatureBase64, String publicKeyBase64) {
    try {
      final publicKey = ed.PublicKey(base64Decode(publicKeyBase64));
      final signature = base64Decode(signatureBase64);
      return ed.verify(publicKey, utf8.encode(message), signature);
    } catch (e) {
      return false;
    }
  }

  /// Sets the shared secret for HMAC communication with the Router.
  Future<void> setSharedSecret(String secret) async {
    await _storage.write(key: _sharedSecretKey, value: secret);
  }

  /// Retrieves the shared secret if it exists.
  Future<String?> getSharedSecret() async {
    return await _storage.read(key: _sharedSecretKey);
  }

  /// Generates an HMAC-SHA256 signature for server requests.
  /// Matches the Router's SecurityMiddleware canonical string format.
  Future<String?> generateHmacSignature({
    required String method,
    required String path,
    required String query,
    required String body,
    required String timestamp,
    required String nonce,
  }) async {
    final secret = await getSharedSecret();
    if (secret == null) return null;

    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    final canonical = [
      timestamp,
      nonce,
      method.toUpperCase(),
      path,
      query,
      bodyHash
    ].join('\n');

    final hmac = Hmac(sha256, utf8.encode(secret));
    final mac = hmac.convert(utf8.encode(canonical)).bytes;

    // Convert to base64url format as used in the Router
    return base64Url.encode(mac).replaceAll('=', '');
  }
}

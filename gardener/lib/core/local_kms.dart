import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure key management system for API credentials.
///
/// Provides encrypted storage and retrieval of sensitive API keys using
/// platform-specific secure storage (iOS Keychain, Android KeyStore, etc.).
///
/// Example:
/// ```dart
/// final kms = LocalKMS();
/// await kms.storeAIKey('sk-...');
/// final key = await kms.getAIKey();
/// ```
class LocalKMS {
  final FlutterSecureStorage _storage;
  static const _aiKeyName = 'ss_ai_kms_key';
  static const _debridKeyName = 'ss_debrid_kms_key';

  /// Creates a new [LocalKMS] instance.
  ///
  /// [storage] - Optional secure storage instance for testing. Defaults to [FlutterSecureStorage].
  LocalKMS({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Securely stores an AI API key (e.g., OpenAI, Anthropic).
  ///
  /// [key] - The API key to store securely.
  Future<void> storeAIKey(String key) async {
    await _storage.write(key: _aiKeyName, value: key);
  }

  /// Retrieves the stored AI API key.
  ///
  /// Returns the key if stored, null otherwise.
  Future<String?> getAIKey() async {
    return await _storage.read(key: _aiKeyName);
  }

  /// Securely stores a Debrid service API key (e.g., Real-Debrid).
  ///
  /// [key] - The API key to store securely.
  Future<void> storeDebridKey(String key) async {
    await _storage.write(key: _debridKeyName, value: key);
  }

  /// Retrieves the stored Debrid API key.
  ///
  /// Returns the key if stored, null otherwise.
  Future<String?> getDebridKey() async {
    return await _storage.read(key: _debridKeyName);
  }

  /// Clears all stored API keys from secure storage.
  ///
  /// This is a destructive operation and cannot be undone.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

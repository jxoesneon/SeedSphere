import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure key management system for API credentials.
///
/// Provides encrypted storage and retrieval of sensitive API keys using
/// platform-specific secure storage (iOS Keychain, Android KeyStore, etc.).
///
/// Falls back to [SharedPreferences] on macOS Debug if Keychain access fails
/// (Error -34018), which is common in non-provisioned development environments.
class LocalKMS {
  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;
  bool _useFallback = false;

  static const _aiKeyName = 'ss_ai_kms_key';
  static const _debridKeyName = 'ss_debrid_kms_key';

  /// Creates a new [LocalKMS] instance.
  ///
  /// [storage] - Optional secure storage instance for testing. Defaults to [FlutterSecureStorage].
  LocalKMS({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// Initializes the fallback storage if needed.
  Future<void> _ensureInitialized() async {
    if (_useFallback && _prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  /// Securely stores an AI API key (e.g., OpenAI, Anthropic).
  Future<void> storeAIKey(String key) async {
    try {
      if (_useFallback) {
        await _ensureInitialized();
        await _prefs?.setString(_aiKeyName, key);
        return;
      }
      await _storage.write(key: _aiKeyName, value: key);
    } on PlatformException catch (e) {
      if (e.code == '-34018') {
        debugPrint(
          '[LocalKMS] Keychain access failed (-34018). Falling back to SharedPreferences.',
        );
        _useFallback = true;
        await storeAIKey(key);
      } else {
        rethrow;
      }
    }
  }

  /// Retrieves the stored AI API key.
  Future<String?> getAIKey() async {
    try {
      if (_useFallback) {
        await _ensureInitialized();
        return _prefs?.getString(_aiKeyName);
      }
      return await _storage.read(key: _aiKeyName);
    } on PlatformException catch (e) {
      if (e.code == '-34018') {
        _useFallback = true;
        return await getAIKey();
      }
      rethrow;
    }
  }

  /// Securely stores a Debrid service API key (e.g., Real-Debrid).
  Future<void> storeDebridKey(String key) async {
    try {
      if (_useFallback) {
        await _ensureInitialized();
        await _prefs?.setString(_debridKeyName, key);
        return;
      }
      await _storage.write(key: _debridKeyName, value: key);
    } on PlatformException catch (e) {
      if (e.code == '-34018') {
        _useFallback = true;
        await storeDebridKey(key);
      } else {
        rethrow;
      }
    }
  }

  /// Retrieves the stored Debrid API key.
  Future<String?> getDebridKey() async {
    try {
      if (_useFallback) {
        await _ensureInitialized();
        return _prefs?.getString(_debridKeyName);
      }
      return await _storage.read(key: _debridKeyName);
    } on PlatformException catch (e) {
      if (e.code == '-34018') {
        _useFallback = true;
        return await getDebridKey();
      }
      rethrow;
    }
  }

  /// Clears all stored API keys.
  Future<void> clearAll() async {
    if (_useFallback) {
      await _ensureInitialized();
      await _prefs?.remove(_aiKeyName);
      await _prefs?.remove(_debridKeyName);
    }
    await _storage.deleteAll();
  }
}

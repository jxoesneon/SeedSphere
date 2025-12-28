import 'package:gardener/core/local_kms.dart';

/// Helper utility for ensuring API keys exist at app startup.
///
/// Checks for required API keys and generates placeholder values if missing.
/// Used during app initialization to prevent crashes from missing configuration.
///
/// Example:
/// ```dart
/// final kms = LocalKMS();
/// await ensureKeysExist(kms);
/// // App can now safely access keys
/// ```
///
/// See also:
/// * [LocalKMS] for key storage and retrieval

/// Ensures that required API keys exist in secure storage.
///
/// [kms] - The key management system to check and update.
///
/// If no AI API key is found, generates a temporary placeholder key.
/// This prevents app crashes during development and first-run scenarios.
///
/// **Note:** Placeholder keys (generated with timestamp prefix) should be
/// replaced with real API keys through the settings UI before actual use.
Future<void> ensureKeysExist(LocalKMS kms) async {
  // Check if AI key exists, generate temporary placeholder if missing
  final aiKey = await kms.getAIKey();
  if (aiKey == null) {
    await kms.storeAIKey('gen_ai_${DateTime.now().millisecondsSinceEpoch}');
  }
}

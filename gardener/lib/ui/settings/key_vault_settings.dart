import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';

/// Secure settings screen for managing API keys and credentials.
///
/// Provides a centralized interface for entering and persisting sensitive
/// information such as Real-Debrid API keys, Orion credentials, and AI keys.
///
/// **Security**:
/// - Uses [FlutterSecureStorage] for encrypted platform-level persistence.
/// - Obscures sensitive input fields by default.
/// - Keys remain on-device (except for authentication).
///
/// **Redesigned with Gardener Design System**:
/// - SettingsTextField for API key inputs
/// - NavigationCard for advanced indexer management
/// - InfoCard for security notice
/// - SectionHeader for organization
class KeyVaultSettings extends StatefulWidget {
  /// Creates a [KeyVaultSettings] widget.
  const KeyVaultSettings({super.key});

  @override
  State<KeyVaultSettings> createState() => _KeyVaultSettingsState();
}

class _KeyVaultSettingsState extends State<KeyVaultSettings> {
  /// Internal instance for secure storage operations.
  final _storage = const FlutterSecureStorage();

  // Text controllers for persisting input state
  final _rdController = TextEditingController();
  final _adController = TextEditingController();
  final _orionKeyController = TextEditingController();
  final _orionIdController = TextEditingController();
  final _openaiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  /// Loads all persisted keys from [FlutterSecureStorage] into the controllers.
  Future<void> _loadKeys() async {
    _rdController.text = await _storage.read(key: 'rd_api_key') ?? '';
    _adController.text = await _storage.read(key: 'ad_api_key') ?? '';
    _orionKeyController.text = await _storage.read(key: 'orion_api_key') ?? '';
    _orionIdController.text = await _storage.read(key: 'orion_user_id') ?? '';
    _openaiController.text = await _storage.read(key: 'openai_api_key') ?? '';
    if (mounted) setState(() {});
  }

  /// Helper for updating a specific key in secure storage.
  Future<void> _saveKey(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  int get _configuredKeysCount {
    int count = 0;
    if (_rdController.text.isNotEmpty) count++;
    if (_adController.text.isNotEmpty) count++;
    if (_orionKeyController.text.isNotEmpty) count++;
    if (_orionIdController.text.isNotEmpty) count++;
    if (_openaiController.text.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('KEY VAULT', style: GoogleFonts.outfit(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security notice
            InfoCard(
              message:
                  'Keys: $_configuredKeysCount/5 configured. All keys are encrypted using platform-secure storage (Keychain/Keystore). They never leave your device except to authenticate with the provider.',
              severity: _configuredKeysCount >= 3
                  ? InfoCardSeverity.success
                  : InfoCardSeverity.info,
              customIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 24),

            // Debrid Section
            const SectionHeader('DEBRID PROVIDERS'),
            const SizedBox(height: 8),
            SettingsTextField(
              controller: _rdController,
              label: 'Real-Debrid API Key',
              hint: 'Enter your RD API key',
              leadingIcon: Icons.cloud_download_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('rd_api_key', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () {
                  // TODO: Implement clipboard paste
                },
              ),
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: _adController,
              label: 'AllDebrid API Key',
              hint: 'Enter your AD API key',
              leadingIcon: Icons.cloud_sync_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('ad_api_key', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () {
                  // TODO: Implement clipboard paste
                },
              ),
            ),
            const SizedBox(height: 32),

            // Orion Section
            const SectionHeader('ORION INDEXER'),
            const SizedBox(height: 8),
            SettingsTextField(
              controller: _orionKeyController,
              label: 'Orion API Key',
              hint: 'Enter your Orion API key',
              leadingIcon: Icons.key_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('orion_api_key', val),
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: _orionIdController,
              label: 'Orion User ID',
              hint: 'Enter your Orion User ID',
              leadingIcon: Icons.person_outline_rounded,
              obscureText: false, // User IDs usually aren't secret
              onChanged: (val) => _saveKey('orion_user_id', val),
            ),
            const SizedBox(height: 32),

            // Management for advanced local indexers
            const SectionHeader('LOCAL INDEXERS'),
            const SizedBox(height: 8),
            NavigationCard(
              icon: Icons.dns_rounded,
              title: 'Torznab / Prowlarr',
              description: 'Manage custom indexer endpoints',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TorznabManager()),
              ),
            ),
            const SizedBox(height: 32),

            // AI Backend Configuration
            const SectionHeader('CORTEX (AI)'),
            const SizedBox(height: 8),
            SettingsTextField(
              controller: _openaiController,
              label: 'OpenAI API Key',
              hint: 'sk-...',
              leadingIcon: Icons.psychology_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('openai_api_key', val),
            ),
          ],
        ),
      ),
    );
  }
}

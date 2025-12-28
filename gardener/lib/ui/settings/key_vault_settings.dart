import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Secure settings screen for managing API keys and credentials.
///
/// Provides a centralized interface for entering and persisting sensitive
/// information such as Real-Debrid API keys, Orion credentials, and AI keys.
///
/// **Security:**
/// - Uses [FlutterSecureStorage] for encrypted platform-level persistence.
/// - Obscures sensitive input fields by default.
/// - Explicitly mentions that keys remain on-device (except for authentication).
///
/// Sections:
/// - **Debrid Providers**: Real-Debrid, AllDebrid.
/// - **Orion Indexer**: Global torrent/magnet search.
/// - **Local Indexers**: Navigation to [TorznabManager].
/// - **Cortex (AI)**: Artificial Intelligence backend configuration.
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
  ///
  /// [key] - The unique identifier for the stored value.
  /// [value] - The raw value to persist.
  Future<void> _saveKey(String key, String value) async {
    await _storage.write(key: key, value: value);
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
            _buildInfoCard(),
            const SizedBox(height: 32),

            // Debrid Section
            _buildSectionHeader('DEBRID PROVIDERS'),
            const SizedBox(height: 8),
            _KeyField(
              label: 'Real-Debrid API Key',
              controller: _rdController,
              icon: Icons.cloud_download_rounded,
              onChanged: (val) => _saveKey('rd_api_key', val),
            ),
            const SizedBox(height: 16),
            _KeyField(
              label: 'AllDebrid API Key',
              controller: _adController,
              icon: Icons.cloud_sync_rounded,
              onChanged: (val) => _saveKey('ad_api_key', val),
            ),
            const SizedBox(height: 32),

            // Orion Section
            _buildSectionHeader('ORION INDEXER'),
            const SizedBox(height: 8),
            _KeyField(
              label: 'Orion API Key',
              controller: _orionKeyController,
              icon: Icons.key_rounded,
              onChanged: (val) => _saveKey('orion_api_key', val),
            ),
            const SizedBox(height: 16),
            _KeyField(
              label: 'Orion User ID',
              controller: _orionIdController,
              obscure: false, // User IDs usually aren't secret
              icon: Icons.person_outline_rounded,
              onChanged: (val) => _saveKey('orion_user_id', val),
            ),
            const SizedBox(height: 32),

            // Management for advanced local indexers
            _buildSectionHeader('LOCAL INDEXERS'),
            const SizedBox(height: 8),
            AethericGlass(
              child: ListTile(
                leading: const Icon(Icons.dns_rounded,
                    color: AethericTheme.aetherBlue),
                title: Text('Torznab / Prowlarr',
                    style: GoogleFonts.outfit(color: Colors.white)),
                subtitle: Text('Manage custom indexer endpoints.',
                    style: GoogleFonts.outfit(
                        color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white30, size: 16),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TorznabManager())),
              ),
            ),
            const SizedBox(height: 32),

            // AI Backend Configuration
            _buildSectionHeader('CORTEX (AI)'),
            const SizedBox(height: 8),
            _KeyField(
              label: 'OpenAI API Key',
              controller: _openaiController,
              icon: Icons.psychology_rounded,
              onChanged: (val) => _saveKey('openai_api_key', val),
            ),
          ],
        ),
      ),
    );
  }

  /// Information alert explaining the security model of the Key Vault.
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AethericTheme.aetherBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AethericTheme.aetherBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AethericTheme.aetherBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keys are encrypted using platform-secure storage (Keychain/Keystore). They never leave your device except to authenticate with the provider.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper for building stylized section headers.
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: AethericTheme.aetherBlue,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 12,
      ),
    );
  }
}

/// A custom stylized text field for entering sensitive keys.
class _KeyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final Function(String) onChanged;

  const _KeyField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AethericGlass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            icon: Icon(icon, color: Colors.white54),
            // Paste shortcut for convenience
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste_rounded, color: Colors.white30),
              onPressed: () async {
                // TODO: Implement clipboard paste integration
              },
            ),
          ),
        ),
      ),
    );
  }
}

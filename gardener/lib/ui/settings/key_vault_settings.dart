import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:gardener/core/config_manager.dart';
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
  final _config = ConfigManager();

  // Text controllers for persisting input state
  final _rdController = TextEditingController();
  final _adController = TextEditingController();
  final _pmController = TextEditingController();
  final _orionKeyController = TextEditingController();
  final _orionIdController = TextEditingController();
  final _openaiController = TextEditingController();

  String _activeDebridService = 'real_debrid';

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  /// Loads all persisted keys via ConfigManager.
  Future<void> _loadKeys() async {
    _rdController.text = await _config.getRealDebridToken() ?? '';
    _adController.text = await _config.getAllDebridApiKey() ?? '';
    _pmController.text = await _config.getPremiumizeApiKey() ?? '';
    _orionKeyController.text = await _config.getOrionApiKey() ?? '';
    _orionIdController.text = _config.orionUserId; // Sync
    _openaiController.text = await _config.getApiKey('openai') ?? '';
    _activeDebridService = _config.debridService;
    if (mounted) setState(() {});
  }

  /// Helper for saving keys via ConfigManager.
  Future<void> _saveKey(String keyType, String value) async {
    switch (keyType) {
      case 'rd':
        await _config.setRealDebridToken(value);
        break;
      case 'ad':
        await _config.setAllDebridApiKey(value);
        break;
      case 'pm':
        await _config.setPremiumizeApiKey(value);
        break;
      case 'orion':
        await _config.setOrionApiKey(value);
        break;
      case 'orion_uid':
        _config.orionUserId = value;
        break;
      case 'openai':
        await _config.setApiKey('openai', value);
        break;
    }
  }

  int get _configuredKeysCount {
    int count = 0;
    if (_rdController.text.isNotEmpty) count++;
    if (_adController.text.isNotEmpty) count++;
    if (_pmController.text.isNotEmpty) count++;
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
          icon: Hero(
            tag: 'settings_icon_keys',
            child: const Icon(Icons.vpn_key_rounded, color: Colors.white70),
          ),
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
                  'Keys: $_configuredKeysCount/6 configured. All keys are encrypted using platform-secure storage (Keychain/Keystore). They never leave your device except to authenticate with the provider.',
              severity: _configuredKeysCount >= 3
                  ? InfoCardSeverity.success
                  : InfoCardSeverity.info,
              customIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 24),

            // Debrid Section
            const SectionHeader('DEBRID PROVIDERS'),
            const SizedBox(height: 16),

            Text(
              'Active Service',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SettingsDropdown<String>(
              value: _activeDebridService,
              items: const ['real_debrid', 'all_debrid', 'premiumize', 'orion'],
              icon: Icons.cloud_done_rounded,
              getLabel: (val) {
                switch (val) {
                  case 'real_debrid':
                    return 'Real-Debrid';
                  case 'all_debrid':
                    return 'AllDebrid';
                  case 'premiumize':
                    return 'Premiumize';
                  case 'orion':
                    return 'Orion';
                  default:
                    return val;
                }
              },
              onChanged: (val) {
                if (val != null) {
                  setState(() => _activeDebridService = val);
                  _config.debridService = val;
                }
              },
            ),
            const SizedBox(height: 16),

            SettingsTextField(
              controller: _rdController,
              label: 'Real-Debrid API Key',
              hint: 'Enter your RD API key',
              leadingIcon: Icons.cloud_download_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('rd', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _rdController.text = data!.text!;
                    await _saveKey('rd', data.text!);
                    if (mounted) setState(() {});
                  }
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
              onChanged: (val) => _saveKey('ad', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _adController.text = data!.text!;
                    await _saveKey('ad', data.text!);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: _pmController,
              label: 'Premiumize API Key',
              hint: 'Enter your Premiumize API key',
              leadingIcon: Icons.cloud_queue_rounded,
              obscureText: true,
              onChanged: (val) => _saveKey('pm', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _pmController.text = data!.text!;
                    await _saveKey('pm', data.text!);
                    if (mounted) setState(() {});
                  }
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
              onChanged: (val) => _saveKey('orion', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _orionKeyController.text = data!.text!;
                    await _saveKey('orion', data.text!);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: _orionIdController,
              label: 'Orion User ID',
              hint: 'Enter your Orion User ID',
              leadingIcon: Icons.person_outline_rounded,
              obscureText: false, // User IDs usually aren't secret
              onChanged: (val) => _saveKey('orion_uid', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _orionIdController.text = data!.text!;
                    await _saveKey('orion_uid', data.text!);
                    if (mounted) setState(() {});
                  }
                },
              ),
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
              onChanged: (val) => _saveKey('openai', val),
              trailing: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white30),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _openaiController.text = data!.text!;
                    await _saveKey('openai', data.text!);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring the Cortex AI assistant.
///
/// Allows users to enable/disable the "Neuro-Link" (AI analysis),
/// select the LLM provider, configure API keys, choose specific models,
/// and adjust the verbosity of AI responses.
///
/// **Redesigned with Gardener Design System**:
/// - Provider-specific API key fields
/// - Latest AI models (December 2025)
/// - Dynamic model list based on provider
/// - DeepSeek preconfigured as free default
class CortexSettings extends StatefulWidget {
  /// Creates a [CortexSettings] widget.
  const CortexSettings({super.key});

  @override
  State<CortexSettings> createState() => _CortexSettingsState();
}

class _CortexSettingsState extends State<CortexSettings> {
  final _storage = const FlutterSecureStorage();

  /// Whether the AI analysis feature is globally enabled.
  bool _neuroLinkEnabled = true;

  /// The currently selected LLM provider.
  String _selectedProvider = 'DeepSeek'; // Default to DeepSeek

  /// The currently selected model for the provider.
  String? _selectedModel;

  /// Verbosity level of the AI (0: Concise, 1: Balanced, 2: Verbose).
  double _detailLevel = 1.0;

  // API Key controllers
  final TextEditingController _deepseekKeyController = TextEditingController();
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _anthropicKeyController = TextEditingController();
  final TextEditingController _googleKeyController = TextEditingController();
  final TextEditingController _xaiKeyController = TextEditingController();
  final TextEditingController _mistralKeyController = TextEditingController();
  final TextEditingController _metaKeyController = TextEditingController();
  final TextEditingController _cohereKeyController = TextEditingController();

  /// List of supported AI providers.
  final List<String> _providers = [
    'DeepSeek', // Free default
    'OpenAI',
    'Anthropic',
    'Google',
    'xAI',
    'Mistral',
    'Meta',
    'Cohere',
  ];

  /// Model lists per provider (December 2025)
  final Map<String, List<String>> _providerModels = {
    'DeepSeek': [
      'deepseek-chat', // V3.2 - Free
      'deepseek-reasoner', // R1
      'deepseek-v3',
    ],
    'OpenAI': [
      'gpt-5.2',
      'gpt-5.2-codex',
      'gpt-5-mini',
      'gpt-4.1',
      'gpt-4.1-mini',
    ],
    'Anthropic': [
      'claude-opus-4.5',
      'claude-sonnet-4.5',
      'claude-haiku-4.5',
      'claude-opus-4.1',
    ],
    'Google': [
      'gemini-3-pro',
      'gemini-3-flash',
      'gemini-3-deep-think',
      'gemini-2.5-pro',
    ],
    'xAI': [
      'grok-4.20',
      'grok-4.1',
      'grok-4.1-fast',
    ],
    'Mistral': [
      'mistral-large-3',
      'minstral-14b',
      'minstral-8b',
      'minstral-3b',
    ],
    'Meta': [
      'llama-4-scout',
      'llama-3.3',
      'llama-3.1',
    ],
    'Cohere': [
      'command-r-plus',
      'command-r',
      'command-a',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadKeys();
    _selectedModel = _providerModels[_selectedProvider]!.first;
  }

  Future<void> _loadKeys() async {
    _deepseekKeyController.text =
        await _storage.read(key: 'deepseek_api_key') ?? '';
    _openaiKeyController.text =
        await _storage.read(key: 'openai_api_key') ?? '';
    _anthropicKeyController.text =
        await _storage.read(key: 'anthropic_api_key') ?? '';
    _googleKeyController.text =
        await _storage.read(key: 'google_api_key') ?? '';
    _xaiKeyController.text = await _storage.read(key: 'xai_api_key') ?? '';
    _mistralKeyController.text =
        await _storage.read(key: 'mistral_api_key') ?? '';
    _metaKeyController.text = await _storage.read(key: 'meta_api_key') ?? '';
    _cohereKeyController.text =
        await _storage.read(key: 'cohere_api_key') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _saveKey(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  String get _currentProviderKey {
    switch (_selectedProvider) {
      case 'DeepSeek':
        return _deepseekKeyController.text;
      case 'OpenAI':
        return _openaiKeyController.text;
      case 'Anthropic':
        return _anthropicKeyController.text;
      case 'Google':
        return _googleKeyController.text;
      case 'xAI':
        return _xaiKeyController.text;
      case 'Mistral':
        return _mistralKeyController.text;
      case 'Meta':
        return _metaKeyController.text;
      case 'Cohere':
        return _cohereKeyController.text;
      default:
        return '';
    }
  }

  bool get _hasCurrentProviderKey => _currentProviderKey.isNotEmpty;

  bool get _isFreeProvider => _selectedProvider == 'DeepSeek';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('CORTEX NEURO-LINK',
            style: GoogleFonts.outfit(letterSpacing: 2)),
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
            // Info card explaining Cortex
            InfoCard(
              message: _isFreeProvider
                  ? 'Cortex Neuro-Link is preconfigured with DeepSeek\'s free API for immediate use. Use AI to analyze and enhance swarm content metadata.'
                  : 'Cortex Neuro-Link uses AI to analyze and enhance swarm content metadata. Configure your AI provider API key below.',
              severity: _isFreeProvider
                  ? InfoCardSeverity.success
                  : (_hasCurrentProviderKey
                      ? InfoCardSeverity.success
                      : InfoCardSeverity.warning),
              customIcon: Icons.psychology_rounded,
            ),
            const SizedBox(height: 24),

            // Feature Toggle
            SettingsToggle(
              title: 'Enable Neuro-Link',
              description:
                  'Allow AI to analyze and summarize swarm content metadata',
              value: _neuroLinkEnabled,
              leadingIcon: Icons.auto_awesome_rounded,
              onChanged: (val) => setState(() => _neuroLinkEnabled = val),
            ),
            const SizedBox(height: 32),

            // Provider Selection
            const SectionHeader('COGNITIVE SOURCE'),
            const SizedBox(height: 8),
            SettingsDropdown<String>(
              value: _selectedProvider,
              items: _providers,
              icon: Icons.hub_rounded,
              getLabel: (provider) =>
                  provider == 'DeepSeek' ? '$provider (Free)' : provider,
              onChanged: (val) {
                setState(() {
                  _selectedProvider = val!;
                  _selectedModel = _providerModels[val]!.first;
                });
              },
            ),
            const SizedBox(height: 12),

            // Provider-specific API Key (skip for DeepSeek as it's free/preconfigured)
            if (!_isFreeProvider) ...[
              _buildProviderApiKeyField(),
              const SizedBox(height: 32),
            ],

            // Model Selection (always shown for free provider, conditional for others)
            if (_isFreeProvider || _hasCurrentProviderKey) ...[
              const SectionHeader('MODEL SELECTION'),
              const SizedBox(height: 8),
              SettingsDropdown<String>(
                value: _selectedModel!,
                items: _providerModels[_selectedProvider]!,
                icon: Icons.psychology_alt_rounded,
                getLabel: (model) => model,
                onChanged: (val) => setState(() => _selectedModel = val!),
              ),
              const SizedBox(height: 32),

              // Personality Adjustment
              const SectionHeader('RESPONSE PERSONALITY'),
              const SizedBox(height: 8),
              SettingsSlider(
                value: _detailLevel,
                min: 0,
                max: 2,
                divisions: 2,
                label: 'Detail Level',
                discreteLabels: {
                  0.0: 'Concise',
                  1.0: 'Balanced',
                  2.0: 'Verbose',
                },
                onChanged: (val) => setState(() => _detailLevel = val),
              ),
            ] else ...[
              InfoCard(
                message:
                    'Configure your $_selectedProvider API key above to enable model selection and AI features.',
                severity: InfoCardSeverity.info,
                customIcon: Icons.arrow_upward_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderApiKeyField() {
    String label, hint, storageKey;

    switch (_selectedProvider) {
      case 'OpenAI':
        label = 'OpenAI API Key';
        hint = 'sk-proj-...';
        storageKey = 'openai_api_key';
        break;
      case 'Anthropic':
        label = 'Anthropic API Key';
        hint = 'sk-ant-...';
        storageKey = 'anthropic_api_key';
        break;
      case 'Google':
        label = 'Google AI API Key';
        hint = 'AIza...';
        storageKey = 'google_api_key';
        break;
      case 'xAI':
        label = 'xAI API Key';
        hint = 'xai-...';
        storageKey = 'xai_api_key';
        break;
      case 'Mistral':
        label = 'Mistral API Key';
        hint = 'mistral-...';
        storageKey = 'mistral_api_key';
        break;
      case 'Meta':
        label = 'Meta API Key';
        hint = 'meta-...';
        storageKey = 'meta_api_key';
        break;
      case 'Cohere':
        label = 'Cohere API Key';
        hint = 'cohere-...';
        storageKey = 'cohere_api_key';
        break;
      default:
        return const SizedBox.shrink();
    }

    final controller = _getControllerForProvider(_selectedProvider);

    return SettingsTextField(
      controller: controller,
      label: label,
      hint: hint,
      leadingIcon: Icons.key_rounded,
      obscureText: true,
      onChanged: (val) {
        _saveKey(storageKey, val);
        setState(() {}); // Refresh to show/hide model selection
      },
    );
  }

  TextEditingController _getControllerForProvider(String provider) {
    switch (provider) {
      case 'DeepSeek':
        return _deepseekKeyController;
      case 'OpenAI':
        return _openaiKeyController;
      case 'Anthropic':
        return _anthropicKeyController;
      case 'Google':
        return _googleKeyController;
      case 'xAI':
        return _xaiKeyController;
      case 'Mistral':
        return _mistralKeyController;
      case 'Meta':
        return _metaKeyController;
      case 'Cohere':
        return _cohereKeyController;
      default:
        return TextEditingController();
    }
  }
}

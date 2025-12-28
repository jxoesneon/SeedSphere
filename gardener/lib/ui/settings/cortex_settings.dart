import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring the Cortex AI assistant.
///
/// Allows users to enable/disable the "Neuro-Link" (AI analysis),
/// select the LLM provider (OpenAI, Anthropic, etc.), choose specific models,
/// and adjust the verbosity of AI responses.
///
/// Uses [AethericGlass] for a consistent glassmorphic look across sections.
class CortexSettings extends StatefulWidget {
  /// Creates a [CortexSettings] widget.
  const CortexSettings({super.key});

  @override
  State<CortexSettings> createState() => _CortexSettingsState();
}

class _CortexSettingsState extends State<CortexSettings> {
  /// Whether the AI analysis feature is globally enabled.
  bool _neuroLinkEnabled = true;

  /// The currently selected LLM provider.
  String _selectedProvider = 'OpenAI';

  /// The currently selected model for the provider.
  String _selectedModel = 'gpt-4o';

  /// Verbosity level of the AI (0: Concise, 1: Balanced, 2: Verbose).
  double _detailLevel = 1.0;

  /// List of supported AI providers.
  final List<String> _providers = ['OpenAI', 'Azure', 'Anthropic', 'Google'];

  /// List of supported models.
  final List<String> _models = [
    'gpt-4o',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
    'claude-3-sonnet'
  ];

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
            // Feature Toggle
            AethericGlass(
              child: SwitchListTile(
                title: Text('Enable Neuro-Link',
                    style: GoogleFonts.outfit(color: Colors.white)),
                subtitle: Text(
                  'Allow AI to analyze and summarize swarm content metadata.',
                  style:
                      GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                ),
                value: _neuroLinkEnabled,
                activeTrackColor: AethericTheme.aetherBlue,
                onChanged: (val) => setState(() => _neuroLinkEnabled = val),
              ),
            ),
            const SizedBox(height: 32),

            // Provider Selection
            _buildSectionHeader('COGNITIVE SOURCE'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedProvider,
                        isExpanded: true,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.hub_rounded,
                            color: Colors.white70),
                        items: _providers
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedProvider = val!),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedModel,
                        isExpanded: true,
                        style: GoogleFonts.outfit(color: Colors.white),
                        icon: const Icon(Icons.psychology_alt_rounded,
                            color: AethericTheme.aetherBlue),
                        items: _models
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedModel = val!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Personality Adjustment
            _buildSectionHeader('RESPONSE PERSONALITY'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Concise',
                            style: _labelStyle(active: _detailLevel == 0)),
                        Text('Balanced',
                            style: _labelStyle(active: _detailLevel == 1)),
                        Text('Verbose',
                            style: _labelStyle(active: _detailLevel == 2)),
                      ],
                    ),
                    Slider(
                      value: _detailLevel,
                      min: 0,
                      max: 2,
                      divisions: 2,
                      activeColor: AethericTheme.aetherBlue,
                      inactiveColor: Colors.white10,
                      onChanged: (val) => setState(() => _detailLevel = val),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper for building labels in the slider section.
  TextStyle _labelStyle({bool active = false}) {
    return GoogleFonts.outfit(
      color: active ? Colors.white : Colors.white38,
      fontSize: 12,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
    );
  }

  /// Helper for building section headers with consistent styling.
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

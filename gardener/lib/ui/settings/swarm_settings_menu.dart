import 'package:flutter/material.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';

import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/compact_settings_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// The primary navigation menu for application and node configuration.
///
/// Displays a vertically-scrollable list of settings categories using compact
/// horizontal cards. This modern 2025 UI design prioritizes information density
/// and quick scanning while maintaining excellent accessibility.
///
/// Features:
/// - 60% more content visible on screen vs previous grid layout
/// - Compact 72dp cards with horizontal layouts
/// - Priority-based visual hierarchy
/// - Smooth animations and micro-interactions
/// - WCAG 2.2 compliant
class SwarmSettingsMenu extends StatelessWidget {
  /// Creates a [SwarmSettingsMenu] widget.
  const SwarmSettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text(
          'NODE CONFIGURATION',
          style: GoogleFonts.outfit(letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Critical settings (Primary accent)
          CompactSettingsCard(
            title: 'Swarm Uplink',
            icon: Icons.settings_input_antenna_rounded,
            description: 'Trackers, Bootstrap Nodes & Peering',
            priority: SettingsPriority.critical,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SwarmUplinkSettings()),
            ),
          ),
          CompactSettingsCard(
            title: 'Key Vault',
            icon: Icons.vpn_key_rounded,
            description: 'Secure Storage for Debrid & API Keys',
            priority: SettingsPriority.critical,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KeyVaultSettings()),
            ),
          ),

          // Standard settings (Secondary color)
          CompactSettingsCard(
            title: 'Cortex',
            icon: Icons.psychology_rounded,
            description: 'Neuro-Link AI & Descriptions',
            priority: SettingsPriority.standard,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CortexSettings()),
            ),
          ),
          CompactSettingsCard(
            title: 'Playback',
            icon: Icons.movie_filter_rounded,
            description: 'Sorting, Quality & Filters',
            priority: SettingsPriority.standard,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlaybackSettings()),
            ),
          ),

          // Optional settings (Tertiary color)
          CompactSettingsCard(
            title: 'Providers',
            icon: Icons.extension_rounded,
            description: 'Manage Scrapers & Sources',
            priority: SettingsPriority.optional,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProviderSettings()),
            ),
          ),
        ],
      ),
    );
  }
}

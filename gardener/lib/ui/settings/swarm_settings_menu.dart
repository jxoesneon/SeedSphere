import 'package:flutter/material.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/playback_settings.dart';

import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// The primary navigation menu for application and node configuration.
///
/// Displays a grid of settings categories, each represented by a card.
/// This screen serves as the gateway to the more granular configuration
/// pages like [SwarmUplinkSettings], [KeyVaultSettings], [CortexSettings],
/// and [PlaybackSettings].
///
/// Uses [AethericGlass] and a 2-column grid layout for a premium dashboard feel.
class SwarmSettingsMenu extends StatelessWidget {
  /// Creates a [SwarmSettingsMenu] widget.
  const SwarmSettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('NODE CONFIGURATION',
            style: GoogleFonts.outfit(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _SettingsCard(
            title: 'Swarm Uplink',
            icon: Icons.settings_input_antenna_rounded,
            description: 'Trackers, Bootstrap Nodes & Peering',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SwarmUplinkSettings())),
          ),
          _SettingsCard(
            title: 'Key Vault',
            icon: Icons.vpn_key_rounded,
            description: 'Secure Storage for Debrid & API Keys',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const KeyVaultSettings())),
          ),
          _SettingsCard(
            title: 'Cortex',
            icon: Icons.psychology_rounded,
            description: 'Neuro-Link AI & Descriptions',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CortexSettings())),
          ),
          _SettingsCard(
            title: 'Playback',
            icon: Icons.movie_filter_rounded,
            description: 'Sorting, Quality & Filters',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlaybackSettings())),
          ),
          _SettingsCard(
            title: 'Providers',
            icon: Icons.extension_rounded,
            description: 'Manage Scrapers & Sources',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProviderSettings())),
          ),
        ],
      ),
    );
  }
}

/// A specialized glassmorphic card for settings navigation.
class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AethericGlass(
      borderRadius: 24,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AethericTheme.aetherBlue),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

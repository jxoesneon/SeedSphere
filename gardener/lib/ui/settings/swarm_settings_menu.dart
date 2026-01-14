import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/ui/settings/cortex_settings.dart';
import 'package:gardener/ui/settings/key_vault_settings.dart';
import 'package:gardener/ui/settings/debug_logs_screen.dart';
import 'package:gardener/ui/settings/playback_settings.dart';
import 'package:gardener/ui/settings/provider_settings.dart';
import 'package:gardener/ui/settings/optimization_settings.dart';
import 'package:gardener/ui/settings/swarm_uplink_settings.dart';
import 'package:gardener/ui/settings/torznab_manager.dart';
import 'package:gardener/ui/settings/addon_settings.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/compact_settings_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// The primary navigation menu for application and node configuration.
///
/// **UX Redesign (Phase 13)**:
/// - Categorized into Core, Experience, and System zones.
/// - Live metrics (Peers, Active Providers, AI Choice) on cards.
/// - Spatial consistency with Hero animations.
/// - CustomScrollView for fluid scrolling.
class SwarmSettingsMenu extends ConsumerStatefulWidget {
  /// Creates a [SwarmSettingsMenu] widget.
  const SwarmSettingsMenu({super.key});

  @override
  ConsumerState<SwarmSettingsMenu> createState() => _SwarmSettingsMenuState();
}

class _SwarmSettingsMenuState extends ConsumerState<SwarmSettingsMenu> {
  final _config = ConfigManager();

  @override
  Widget build(BuildContext context) {
    final peerCount = ref.watch(p2pManagerProvider).peerCount;

    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Dynamic Glass AppBar
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: AethericTheme.deepVoid.withValues(alpha: 0.8),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'NODE CONFIGURATION',
                style: GoogleFonts.outfit(
                  letterSpacing: 2,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AethericTheme.aetherBlue.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // ZONE 1: NODE CORE
          const SliverToBoxAdapter(
            child: _SettingsSectionHeader('ENGINE ROOM'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ValueListenableBuilder<int>(
                  valueListenable: peerCount,
                  builder: (context, value, _) {
                    return CompactSettingsCard(
                      title: 'Swarm Uplink',
                      icon: Icons.settings_input_antenna_rounded,
                      description: 'Trackers, Bootstrap & Peering',
                      priority: SettingsPriority.critical,
                      heroTag: 'settings_icon_uplink',
                      statusBadge: '$value Peers',
                      badgeColor: value > 0
                          ? AethericTheme.kryptonGreen
                          : Colors.orange,
                      onTap: () =>
                          _navigateTo(context, const SwarmUplinkSettings()),
                    );
                  },
                ),
                CompactSettingsCard(
                  title: 'Content Sources',
                  icon: Icons.extension_rounded,
                  description: 'Manage Scrapers & Providers',
                  priority: SettingsPriority.standard,
                  heroTag: 'settings_icon_providers',
                  statusBadge: '${_config.activeProvidersCount} Active',
                  onTap: () => _navigateTo(context, const ProviderSettings()),
                ),
                CompactSettingsCard(
                  title: 'Key Vault',
                  icon: Icons.vpn_key_rounded,
                  description: 'Secure Storage for API Keys',
                  priority: SettingsPriority.optional,
                  heroTag: 'settings_icon_keys',
                  onTap: () => _navigateTo(context, const KeyVaultSettings()),
                ),
                CompactSettingsCard(
                  title: 'Indexer Mesh',
                  icon: Icons.dns_rounded,
                  description: 'Jackett & Prowlarr Endpoints',
                  priority: SettingsPriority.optional,
                  heroTag: 'settings_icon_mesh',
                  statusBadge: _config.enableTorznab ? 'Active' : null,
                  onTap: () => _navigateTo(context, const TorznabManager()),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ZONE 2: EXPERIENCE
          const SliverToBoxAdapter(child: _SettingsSectionHeader('EXPERIENCE')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CompactSettingsCard(
                  title: 'Cortex Neuro-Link',
                  icon: Icons.psychology_rounded,
                  description: 'AI Analysis & Intelligence',
                  priority: SettingsPriority.critical,
                  heroTag: 'settings_icon_cortex',
                  statusBadge: _config.cortexProvider,
                  onTap: () => _navigateTo(context, const CortexSettings()),
                ),
                CompactSettingsCard(
                  title: 'Stremio Addon',
                  icon: Icons.layers_rounded,
                  description: 'Catalogs & Dynamic Lists',
                  priority: SettingsPriority.standard,
                  heroTag: 'settings_icon_addon',
                  onTap: () => _navigateTo(context, const AddonSettings()),
                ),
                CompactSettingsCard(
                  title: 'Playback Protocols',
                  icon: Icons.movie_filter_rounded,
                  description: 'Sorting, Quality & Filters',
                  priority: SettingsPriority.standard,
                  heroTag: 'settings_icon_playback',
                  onTap: () => _navigateTo(context, const PlaybackSettings()),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ZONE 3: SYSTEM
          const SliverToBoxAdapter(child: _SettingsSectionHeader('SYSTEM')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                CompactSettingsCard(
                  title: 'Optimization',
                  icon: Icons.speed_rounded,
                  description: 'Validation & Swarm Health',
                  priority: SettingsPriority.optional,
                  heroTag: 'settings_icon_opt',
                  onTap: () =>
                      _navigateTo(context, const OptimizationSettings()),
                ),
                CompactSettingsCard(
                  title: 'Debug Console',
                  icon: Icons.bug_report_rounded,
                  description: 'System Records & Logs',
                  priority: SettingsPriority.optional,
                  heroTag: 'settings_icon_debug',
                  onTap: () => _navigateTo(context, const DebugLogsScreen()),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      // Refresh state when coming back (e.g. if providers were changed)
      setState(() {});
    });
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  const _SettingsSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: AethericTheme.aetherBlue.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

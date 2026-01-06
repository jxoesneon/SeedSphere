import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring content providers/scrapers.
///
/// **Redesigned with Gardener Design System**:
/// - ExpandableSection for provider grouping
/// - SettingsToggle for enable/disable
/// - InfoCard showing active provider count
/// - Organized by content type
class ProviderSettings extends StatefulWidget {
  const ProviderSettings({super.key});

  @override
  State<ProviderSettings> createState() => _ProviderSettingsState();
}

class _ProviderSettingsState extends State<ProviderSettings> {
  // Movies & TV providers
  bool _torrentioEnabled = true;
  bool _ytsEnabled = true;
  bool _eztvEnabled = true;

  // Anime providers
  bool _nyaaEnabled = true;
  bool _anidexEnabled = true;
  bool _tokyoToshoEnabled = true;

  // General providers
  bool _x1337Enabled = true;
  bool _pirateBayEnabled = false;
  bool _torrentGalaxyEnabled = true;
  bool _torlockEnabled = true;
  bool _magnetDLEnabled = true;
  bool _zooqleEnabled = false;
  bool _rutorEnabled = false;

  int get _activeProvidersCount {
    int count = 0;
    if (_torrentioEnabled) count++;
    if (_ytsEnabled) count++;
    if (_eztvEnabled) count++;
    if (_nyaaEnabled) count++;
    if (_anidexEnabled) count++;
    if (_tokyoToshoEnabled) count++;
    if (_x1337Enabled) count++;
    if (_pirateBayEnabled) count++;
    if (_torrentGalaxyEnabled) count++;
    if (_torlockEnabled) count++;
    if (_magnetDLEnabled) count++;
    if (_zooqleEnabled) count++;
    if (_rutorEnabled) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text(
          'CONTENT PROVIDERS',
          style: GoogleFonts.outfit(letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status info
            InfoCard(
              message:
                  'Active Providers: $_activeProvidersCount/13. More providers = better search results but slower queries.',
              severity: _activeProvidersCount >= 8
                  ? InfoCardSeverity.success
                  : InfoCardSeverity.warning,
              customIcon: Icons.hub_rounded,
            ),
            const SizedBox(height: 24),

            // Movies & TV Section
            ExpandableSection(
              title: 'Movies & TV',
              icon: Icons.movie_rounded,
              initiallyExpanded: true,
              badge:
                  '${[_torrentioEnabled, _ytsEnabled, _eztvEnabled].where((e) => e).length}/3',
              child: Column(
                children: [
                  SettingsToggle(
                    title: 'Torrentio',
                    description: 'Aggregator for movies & series',
                    value: _torrentioEnabled,
                    leadingIcon: Icons.hub,
                    onChanged: (v) => setState(() => _torrentioEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'YTS',
                    description: 'High quality movie encodes',
                    value: _ytsEnabled,
                    leadingIcon: Icons.movie,
                    onChanged: (v) => setState(() => _ytsEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'EZTV',
                    description: 'TV Series specialist',
                    value: _eztvEnabled,
                    leadingIcon: Icons.tv,
                    onChanged: (v) => setState(() => _eztvEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Anime Section
            ExpandableSection(
              title: 'Anime',
              icon: Icons.animation_rounded,
              badge:
                  '${[_nyaaEnabled, _anidexEnabled, _tokyoToshoEnabled].where((e) => e).length}/3',
              child: Column(
                children: [
                  SettingsToggle(
                    title: 'Nyaa',
                    description: 'Anime & East Asian media',
                    value: _nyaaEnabled,
                    leadingIcon: Icons.animation,
                    onChanged: (v) => setState(() => _nyaaEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'AniDex',
                    description: 'Specialized Anime Tracker',
                    value: _anidexEnabled,
                    leadingIcon: Icons.animation,
                    onChanged: (v) => setState(() => _anidexEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'TokyoTosho',
                    description: 'Japanese media tracker',
                    value: _tokyoToshoEnabled,
                    leadingIcon: Icons.translate,
                    onChanged: (v) => setState(() => _tokyoToshoEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // General Providers Section
            ExpandableSection(
              title: 'General',
              icon: Icons.public_rounded,
              badge:
                  '${[_x1337Enabled, _torrentGalaxyEnabled, _torlockEnabled, _magnetDLEnabled, _zooqleEnabled, _rutorEnabled, _pirateBayEnabled].where((e) => e).length}/7',
              child: Column(
                children: [
                  SettingsToggle(
                    title: '1337x',
                    description: 'General purpose community',
                    value: _x1337Enabled,
                    leadingIcon: Icons.public,
                    onChanged: (v) => setState(() => _x1337Enabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'TorrentGalaxy',
                    description: 'Popular general tracker',
                    value: _torrentGalaxyEnabled,
                    leadingIcon: Icons.stars,
                    onChanged: (v) => setState(() => _torrentGalaxyEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Torlock',
                    description: 'Verified torrents only',
                    value: _torlockEnabled,
                    leadingIcon: Icons.lock,
                    onChanged: (v) => setState(() => _torlockEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'MagnetDL',
                    description: 'Fast magnet link search',
                    value: _magnetDLEnabled,
                    leadingIcon: Icons.link,
                    onChanged: (v) => setState(() => _magnetDLEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Zooqle',
                    description: 'Verified movies & TV',
                    value: _zooqleEnabled,
                    leadingIcon: Icons.check_circle,
                    onChanged: (v) => setState(() => _zooqleEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Rutor',
                    description: 'Russian/International tracker',
                    value: _rutorEnabled,
                    leadingIcon: Icons.language,
                    onChanged: (v) => setState(() => _rutorEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'The Pirate Bay',
                    description: 'Legacy tracker (ISP blocks common)',
                    value: _pirateBayEnabled,
                    leadingIcon: Icons.flag_circle,
                    isWarning: true,
                    onChanged: (v) => setState(() => _pirateBayEnabled = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

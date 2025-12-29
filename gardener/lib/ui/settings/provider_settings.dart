import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring content providers/scrapers.
class ProviderSettings extends StatefulWidget {
  const ProviderSettings({super.key});

  @override
  State<ProviderSettings> createState() => _ProviderSettingsState();
}

class _ProviderSettingsState extends State<ProviderSettings> {
  // Demo state - in real app would verify against actual provider manager
  bool _torrentioEnabled = true;
  bool _ytsEnabled = true;
  bool _eztvEnabled = true;
  bool _nyaaEnabled = true;
  bool _x1337Enabled = true;
  bool _pirateBayEnabled = false;
  bool _torrentGalaxyEnabled = true;
  bool _torlockEnabled = true;
  bool _magnetDLEnabled = true;
  bool _anidexEnabled = true;
  bool _tokyoToshoEnabled = true;
  bool _zooqleEnabled = false;
  bool _rutorEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('CONTENT PROVIDERS',
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
            _buildSectionHeader('ACTIVE SCRAPERS'),
            const SizedBox(height: 16),
            _buildProviderToggle(
              'Torrentio',
              'Aggregator for movies & series',
              _torrentioEnabled,
              (v) => setState(() => _torrentioEnabled = v),
              Icons.hub,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'YTS',
              'High quality movie encodes',
              _ytsEnabled,
              (v) => setState(() => _ytsEnabled = v),
              Icons.movie,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'EZTV',
              'TV Series specialist',
              _eztvEnabled,
              (v) => setState(() => _eztvEnabled = v),
              Icons.tv,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'Nyaa',
              'Anime & East Asian media',
              _nyaaEnabled,
              (v) => setState(() => _nyaaEnabled = v),
              Icons.animation,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              '1337x',
              'General purpose community',
              _x1337Enabled,
              (v) => setState(() => _x1337Enabled = v),
              Icons.public,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'TorrentGalaxy',
              'Popular general tracker',
              _torrentGalaxyEnabled,
              (v) => setState(() => _torrentGalaxyEnabled = v),
              Icons.stars,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'Torlock',
              'Verified torrents only',
              _torlockEnabled,
              (v) => setState(() => _torlockEnabled = v),
              Icons.lock,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'MagnetDL',
              'Fast magnet link search',
              _magnetDLEnabled,
              (v) => setState(() => _magnetDLEnabled = v),
              Icons.link,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'AniDex',
              'Specialized Anime Tracker',
              _anidexEnabled,
              (v) => setState(() => _anidexEnabled = v),
              Icons.animation,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'TokyoTosho',
              'Japanese media tracker',
              _tokyoToshoEnabled,
              (v) => setState(() => _tokyoToshoEnabled = v),
              Icons.translate,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'Zooqle',
              'Verified movies & TV',
              _zooqleEnabled,
              (v) => setState(() => _zooqleEnabled = v),
              Icons.check_circle,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'Rutor',
              'Russian/International tracker',
              _rutorEnabled,
              (v) => setState(() => _rutorEnabled = v),
              Icons.language,
            ),
            const SizedBox(height: 12),
            _buildProviderToggle(
              'The Pirate Bay',
              'Legacy tracker (ISP blocks common)',
              _pirateBayEnabled,
              (v) => setState(() => _pirateBayEnabled = v),
              Icons.flag_circle,
              isWarning: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderToggle(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, IconData icon,
      {bool isWarning = false}) {
    return AethericGlass(
      child: SwitchListTile(
        secondary: Icon(icon,
            color: isWarning ? Colors.orange : AethericTheme.aetherBlue),
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
        ),
        value: value,
        activeTrackColor: isWarning
            ? Colors.orange.withValues(alpha: 0.5)
            : AethericTheme.aetherBlue,
        activeThumbColor: isWarning ? Colors.orange : Colors.white,
        onChanged: onChanged,
      ),
    );
  }

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

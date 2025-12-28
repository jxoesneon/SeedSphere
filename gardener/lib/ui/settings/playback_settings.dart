import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring media playback and stream filtering.
///
/// Allows users to define sorting priorities (e.g., sort by resolution or seeders),
/// global quality filters (exclude cams, 3D), and advanced regex-based
/// inclusion/exclusion rules for stream titles.
///
/// **Sections:**
/// - **Stream Priority**: Sorting logic for search results.
/// - **Quality Filters**: Predefined toggles for common low-quality content.
/// - **Advanced Filtering**: Regex-based rules for expert users.
class PlaybackSettings extends StatefulWidget {
  /// Creates a [PlaybackSettings] widget.
  const PlaybackSettings({super.key});

  @override
  State<PlaybackSettings> createState() => _PlaybackSettingsState();
}

class _PlaybackSettingsState extends State<PlaybackSettings> {
  /// Current sorting criterion for streams.
  String _sortBy = 'Resolution';

  /// Whether to hide theater recordings (CAM/TS).
  bool _excludeCam = true;

  /// Whether to hide 3D Side-by-Side content.
  bool _exclude3D = true;

  /// Whether to prioritize HDR or Dolby Vision versions.
  bool _preferHDR = true;

  /// Regex controller for mandatory string presence in titles.
  final TextEditingController _includeRegex = TextEditingController();

  /// Regex controller for mandatory string absence in titles.
  final TextEditingController _excludeRegex = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text('PLAYBACK PROTOCOLS',
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
            // Sorting Priority
            _buildSectionHeader('STREAM PRIORITY'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _sortBy,
                    isExpanded: true,
                    style: GoogleFonts.outfit(color: Colors.white),
                    icon: const Icon(Icons.sort_rounded,
                        color: AethericTheme.aetherBlue),
                    items: ['Resolution', 'Seeders', 'File Size', 'Date']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) => setState(() => _sortBy = val!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Predefined Quality Filters
            _buildSectionHeader('QUALITY FILTERS'),
            const SizedBox(height: 8),
            _buildToggle(
                'Exclude CAM/Telesync',
                'Hide low quality theater recordings.',
                _excludeCam,
                (v) => setState(() => _excludeCam = v)),
            const SizedBox(height: 8),
            _buildToggle('Exclude 3D SBS', 'Hide 3D Side-by-Side content.',
                _exclude3D, (v) => setState(() => _exclude3D = v)),
            const SizedBox(height: 8),
            _buildToggle(
                'Prefer HDR/Dolby Vision',
                'Prioritize high dynamic range streams.',
                _preferHDR,
                (v) => setState(() => _preferHDR = v)),
            const SizedBox(height: 32),

            // Advanced Regex-based Rules
            _buildSectionHeader('ADVANCED FILTERING'),
            const SizedBox(height: 8),
            AethericGlass(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _includeRegex,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Must Include (Regex)',
                        labelStyle: TextStyle(color: Colors.white54),
                        hintText: 'e.g. (H265|HDR)',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.filter_alt_rounded,
                            color: Colors.greenAccent),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    TextField(
                      controller: _excludeRegex,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Must Exclude (Regex)',
                        labelStyle: TextStyle(color: Colors.white54),
                        hintText: 'e.g. (rarbg|CAM)',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        prefixIcon:
                            Icon(Icons.block_rounded, color: Colors.redAccent),
                      ),
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

  /// Builds a glassmorphic toggle tile for simple boolean settings.
  Widget _buildToggle(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return AethericGlass(
      child: SwitchListTile(
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white)),
        subtitle: Text(subtitle,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
        value: value,
        activeTrackColor: AethericTheme.aetherBlue,
        onChanged: onChanged,
      ),
    );
  }

  /// Builds a section header with the application's accent color and typography.
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

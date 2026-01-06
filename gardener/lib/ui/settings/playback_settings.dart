import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:google_fonts/google_fonts.dart';

/// Settings screen for configuring media playback and stream filtering.
///
/// Allows users to define sorting priorities (e.g., sort by resolution or seeders),
/// global quality filters (exclude cams, 3D), and advanced regex-based
/// inclusion/exclusion rules for stream titles.
///
/// **Redesigned with Gardener Design System**:
/// - SettingsDropdown for stream priority
/// - SettingsToggle for quality filters
/// - ExpandableSection for advanced filtering
/// - InfoCard for guidance
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

  int get _activeFiltersCount {
    int count = 0;
    if (_excludeCam) count++;
    if (_exclude3D) count++;
    if (_preferHDR) count++;
    if (_includeRegex.text.isNotEmpty) count++;
    if (_excludeRegex.text.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      appBar: AppBar(
        title: Text(
          'PLAYBACK PROTOCOLS',
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
            // Info card explaining playback settings
            InfoCard(
              message:
                  'Active Filters: $_activeFiltersCount. Configure how streams are sorted and filtered for optimal playback quality.',
              severity: _activeFiltersCount > 0
                  ? InfoCardSeverity.success
                  : InfoCardSeverity.info,
              customIcon: Icons.tune_rounded,
            ),
            const SizedBox(height: 24),

            // Sorting Priority
            const SectionHeader('STREAM PRIORITY'),
            const SizedBox(height: 8),
            SettingsDropdown<String>(
              value: _sortBy,
              items: const ['Resolution', 'Seeders', 'File Size', 'Date'],
              icon: Icons.sort_rounded,
              getLabel: (item) => item,
              onChanged: (val) => setState(() => _sortBy = val!),
            ),
            const SizedBox(height: 32),

            // Predefined Quality Filters
            const SectionHeader('QUALITY FILTERS'),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Exclude CAM/Telesync',
              description: 'Hide low quality theater recordings',
              value: _excludeCam,
              leadingIcon: Icons.block_rounded,
              onChanged: (v) => setState(() => _excludeCam = v),
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Exclude 3D SBS',
              description: 'Hide 3D Side-by-Side content',
              value: _exclude3D,
              leadingIcon: Icons.view_in_ar_rounded,
              onChanged: (v) => setState(() => _exclude3D = v),
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Prefer HDR/Dolby Vision',
              description: 'Prioritize high dynamic range streams',
              value: _preferHDR,
              leadingIcon: Icons.hdr_on_rounded,
              onChanged: (v) => setState(() => _preferHDR = v),
            ),
            const SizedBox(height: 32),

            // Advanced Regex-based Rules
            const SectionHeader('ADVANCED FILTERING'),
            const SizedBox(height: 8),
            ExpandableSection(
              title: 'Regex Rules',
              icon: Icons.code_rounded,
              collapsedSummary:
                  _includeRegex.text.isEmpty && _excludeRegex.text.isEmpty
                  ? 'No custom rules'
                  : 'Custom rules active',
              badge:
                  (_includeRegex.text.isNotEmpty ||
                      _excludeRegex.text.isNotEmpty)
                  ? 'Active'
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InfoCard(
                    message:
                        'Use regular expressions to include or exclude streams based on their titles. Example: (H265|HDR) to match either term.',
                    severity: InfoCardSeverity.info,
                    customIcon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  SettingsTextField(
                    controller: _includeRegex,
                    label: 'Must Include (Regex)',
                    hint: 'e.g. (H265|HDR)',
                    leadingIcon: Icons.filter_alt_rounded,
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SettingsTextField(
                    controller: _excludeRegex,
                    label: 'Must Exclude (Regex)',
                    hint: 'e.g. (rarbg|CAM)',
                    leadingIcon: Icons.block_rounded,
                    onChanged: (val) => setState(() {}),
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

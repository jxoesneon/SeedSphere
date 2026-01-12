import 'package:flutter/material.dart';
import 'package:gardener/core/config_manager.dart';
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
  final _config = ConfigManager();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _sortBy = _config.sortBy;
    _excludeCam = _config.excludeCam;
    _exclude3D = _config.exclude3D;
    _preferHDR = _config.preferHDR;
    _includeRegex.text = _config.includeRegex;
    _excludeRegex.text = _config.excludeRegex;

    _autoProxy = _config.autoProxy;
    _maxTrackersController.text = _config.maxTrackers.toString();
    _trackerVariant = _config.trackerVariant;
    _customTrackersUrl.text = _config.customTrackersUrl;

    _appendOriginalDesc = _config.appendOriginalDesc;
    _requireDetailsForOriginal = _config.requireDetailsForOriginal;
    _seriesTitleCleanup = _config.seriesTitleCleanup;
    _preferredSource = _config.preferredSourceType;
    _languagesController.text = _config.prioritizedLanguages.join(', ');
  }

  /// Current sorting criterion for streams.
  late String _sortBy;

  /// Whether to hide theater recordings (CAM/TS).
  late bool _excludeCam;

  /// Whether to hide 3D Side-by-Side content.
  late bool _exclude3D;

  /// Whether to prioritize HDR or Dolby Vision versions.
  late bool _preferHDR;

  /// Regex controller for mandatory string presence in titles.
  final TextEditingController _includeRegex = TextEditingController();

  /// Regex controller for mandatory string absence in titles.
  final TextEditingController _excludeRegex = TextEditingController();

  late bool _autoProxy;
  final TextEditingController _maxTrackersController = TextEditingController();
  late String _trackerVariant;
  final TextEditingController _customTrackersUrl = TextEditingController();

  late bool _appendOriginalDesc;
  late bool _requireDetailsForOriginal;
  late bool _seriesTitleCleanup;
  late String _preferredSource;
  final TextEditingController _languagesController = TextEditingController();

  void _saveInt(TextEditingController controller, Function(int) setter) {
    final val = int.tryParse(controller.text);
    if (val != null && val >= 0) setter(val);
  }

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
          icon: Hero(
            tag: 'settings_icon_playback',
            child: const Icon(
              Icons.movie_filter_rounded,
              color: Colors.white70,
            ),
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

            // Stream Processing
            const SectionHeader('STREAM PROCESSING'),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Auto Proxy',
              description: 'Aggregate and enhance streams from providers',
              value: _autoProxy,
              leadingIcon: Icons.compare_arrows_rounded,
              onChanged: (v) {
                setState(() => _autoProxy = v);
                _config.autoProxy = v;
              },
            ),
            if (_autoProxy) ...[
              const SizedBox(height: 8),
              ExpandableSection(
                title: 'Tracker Configuration',
                icon: Icons.radar_rounded,
                child: Column(
                  children: [
                    SettingsDropdown<String>(
                      value: _trackerVariant,
                      items: const [
                        'best_ip',
                        'best',
                        'all_ip',
                        'all',
                        'all_udp',
                        'all_http',
                      ],
                      icon: Icons.list_alt_rounded,
                      getLabel: (v) => v.toUpperCase().replaceAll('_', ' '),
                      onChanged: (v) {
                        setState(() => _trackerVariant = v!);
                        _config.trackerVariant = v!;
                      },
                    ),
                    const SizedBox(height: 12),
                    SettingsTextField(
                      controller: _customTrackersUrl,
                      label: 'Custom Trackers URL',
                      hint: 'https://...',
                      leadingIcon: Icons.link_rounded,
                      onChanged: (v) {
                        setState(() {});
                        _config.customTrackersUrl = v;
                      },
                    ),
                    const SizedBox(height: 12),
                    SettingsTextField(
                      controller: _maxTrackersController,
                      label: 'Max Trackers (0 = Unlimited)',
                      hint: '0',
                      leadingIcon: Icons.onetwothree_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _saveInt(
                        _maxTrackersController,
                        (v) => _config.maxTrackers = v,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Description Formatting
            const SectionHeader('FORMATTING'),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Append Original Description',
              description: 'Keep provider description below generated info',
              value: _appendOriginalDesc,
              leadingIcon: Icons.description_rounded,
              onChanged: (v) {
                setState(() => _appendOriginalDesc = v);
                _config.appendOriginalDesc = v;
              },
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Require Details for Fallback',
              description: 'Use original desc if parsing fails',
              value: _requireDetailsForOriginal,
              leadingIcon: Icons.backup_rounded,
              onChanged: (v) {
                setState(() => _requireDetailsForOriginal = v);
                _config.requireDetailsForOriginal = v;
              },
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Series Title Cleanup',
              description: 'Rename episodes to clean show names (Heuristic)',
              value: _seriesTitleCleanup,
              leadingIcon: Icons.cleaning_services_rounded,
              onChanged: (v) {
                setState(() => _seriesTitleCleanup = v);
                _config.seriesTitleCleanup = v;
              },
            ),
            const SizedBox(height: 32),

            // Content Heuristics
            const SectionHeader('CONTENT HEURISTICS'),
            const SizedBox(height: 8),
            SettingsDropdown<String>(
              value: _preferredSource,
              items: const ['Any', 'Blu-ray', 'WEB-DL', 'HDTV'],
              icon: Icons.high_quality_rounded,
              getLabel: (v) => 'Prefer: ${v.toUpperCase()}',
              onChanged: (v) {
                setState(() => _preferredSource = v!);
                _config.preferredSourceType = v!;
              },
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: _languagesController,
              label: 'Prioritized Languages',
              hint: 'English, Spanish...',
              leadingIcon: Icons.translate_rounded,
              onChanged: (v) {
                _config.prioritizedLanguages = v
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
              },
            ),
            const SizedBox(height: 32),

            // Sorting Priority
            const SectionHeader('STREAM PRIORITY'),
            const SizedBox(height: 8),
            SettingsDropdown<String>(
              value: _sortBy,
              items: const ['Resolution', 'Seeders', 'File Size', 'Date'],
              icon: Icons.sort_rounded,
              getLabel: (item) => item,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _sortBy = val);
                  _config.sortBy = val;
                }
              },
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
              onChanged: (v) {
                setState(() => _excludeCam = v);
                _config.excludeCam = v;
              },
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Exclude 3D SBS',
              description: 'Hide 3D Side-by-Side content',
              value: _exclude3D,
              leadingIcon: Icons.view_in_ar_rounded,
              onChanged: (v) {
                setState(() => _exclude3D = v);
                _config.exclude3D = v;
              },
            ),
            const SizedBox(height: 8),
            SettingsToggle(
              title: 'Prefer HDR/Dolby Vision',
              description: 'Prioritize high dynamic range streams',
              value: _preferHDR,
              leadingIcon: Icons.hdr_on_rounded,
              onChanged: (v) {
                setState(() => _preferHDR = v);
                _config.preferHDR = v;
              },
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
                    onChanged: (val) {
                      setState(() {});
                      _config.includeRegex = val;
                    },
                  ),
                  const SizedBox(height: 12),
                  SettingsTextField(
                    controller: _excludeRegex,
                    label: 'Must Exclude (Regex)',
                    hint: 'e.g. (rarbg|CAM)',
                    leadingIcon: Icons.block_rounded,
                    onChanged: (val) {
                      setState(() {});
                      _config.excludeRegex = val;
                    },
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

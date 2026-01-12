import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/settings/settings.dart';
import 'package:gardener/core/config_manager.dart';
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
  final _config = ConfigManager();

  // Movies & TV providers
  late bool _torrentioEnabled;
  late bool _ytsEnabled;
  late bool _eztvEnabled;

  // Anime providers
  late bool _nyaaEnabled;
  late bool _anidexEnabled;
  late bool _tokyoToshoEnabled;

  // General providers
  late bool _x1337Enabled;
  late bool _pirateBayEnabled;
  late bool _torrentGalaxyEnabled;
  late bool _torlockEnabled;
  late bool _magnetDLEnabled;
  late bool _zooqleEnabled;
  late bool _rutorEnabled;

  // Global settings
  late bool _backgroundDownload;
  late bool _providerFailover;
  late bool _enableTrackerScraping;
  late bool _torznabEnabled;
  final TextEditingController _maxResultsProviderController =
      TextEditingController();
  final TextEditingController _trackerScrapeTimeoutController =
      TextEditingController();
  final TextEditingController _torznabUrlController = TextEditingController();
  final TextEditingController _torznabKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _torrentioEnabled = _config.enableTorrentio;
    _ytsEnabled = _config.enableYts;
    _eztvEnabled = _config.enableEztv;
    _nyaaEnabled = _config.enableNyaa;
    _anidexEnabled = _config.enableAniDex;
    _tokyoToshoEnabled = _config.enableTokyoTosho;
    _x1337Enabled = _config.enable1337x;
    _pirateBayEnabled = _config.enablePirateBay;
    _torrentGalaxyEnabled = _config.enableTorrentGalaxy;
    _torlockEnabled = _config.enableTorlock;
    _magnetDLEnabled = _config.enableMagnetDL;
    _zooqleEnabled = _config.enableZooqle;
    _rutorEnabled = _config.enableRutor;
    _backgroundDownload = _config.backgroundDownload;
    _providerFailover = _config.providerFailover;
    _enableTrackerScraping = _config.enableTrackerScraping;
    _maxResultsProviderController.text = _config.maxResultsPerProvider
        .toString();
    _trackerScrapeTimeoutController.text = _config.trackerScrapeTimeoutMs
        .toString();
    _torznabEnabled = _config.enableTorznab;
    _torznabUrlController.text = _config.torznabUrl;
    _loadTorznabKey();
  }

  Future<void> _loadTorznabKey() async {
    _torznabKeyController.text = await _config.getTorznabKey() ?? '';
    if (mounted) setState(() {});
  }

  void _saveInt(TextEditingController controller, Function(int) setter) {
    final val = int.tryParse(controller.text);
    if (val != null && val >= 0) setter(val);
  }

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
          icon: Hero(
            tag: 'settings_icon_providers',
            child: const Icon(Icons.extension_rounded, color: Colors.white70),
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
                    onChanged: (v) {
                      setState(() => _torrentioEnabled = v);
                      _config.enableTorrentio = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'YTS',
                    description: 'High quality movie encodes',
                    value: _ytsEnabled,
                    leadingIcon: Icons.movie,
                    onChanged: (v) {
                      setState(() => _ytsEnabled = v);
                      _config.enableYts = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'EZTV',
                    description: 'TV Series specialist',
                    value: _eztvEnabled,
                    leadingIcon: Icons.tv,
                    onChanged: (v) {
                      setState(() => _eztvEnabled = v);
                      _config.enableEztv = v;
                    },
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
                    onChanged: (v) {
                      setState(() => _nyaaEnabled = v);
                      _config.enableNyaa = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'AniDex',
                    description: 'Specialized Anime Tracker',
                    value: _anidexEnabled,
                    leadingIcon: Icons.animation,
                    onChanged: (v) {
                      setState(() => _anidexEnabled = v);
                      _config.enableAniDex = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'TokyoTosho',
                    description: 'Japanese media tracker',
                    value: _tokyoToshoEnabled,
                    leadingIcon: Icons.translate,
                    onChanged: (v) {
                      setState(() => _tokyoToshoEnabled = v);
                      _config.enableTokyoTosho = v;
                    },
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
                    onChanged: (v) {
                      setState(() => _x1337Enabled = v);
                      _config.enable1337x = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'TorrentGalaxy',
                    description: 'Popular general tracker',
                    value: _torrentGalaxyEnabled,
                    leadingIcon: Icons.stars,
                    onChanged: (v) {
                      setState(() => _torrentGalaxyEnabled = v);
                      _config.enableTorrentGalaxy = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Torlock',
                    description: 'Verified torrents only',
                    value: _torlockEnabled,
                    leadingIcon: Icons.lock,
                    onChanged: (v) {
                      setState(() => _torlockEnabled = v);
                      _config.enableTorlock = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'MagnetDL',
                    description: 'Fast magnet link search',
                    value: _magnetDLEnabled,
                    leadingIcon: Icons.link,
                    onChanged: (v) {
                      setState(() => _magnetDLEnabled = v);
                      _config.enableMagnetDL = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Zooqle',
                    description: 'Verified movies & TV',
                    value: _zooqleEnabled,
                    leadingIcon: Icons.check_circle,
                    onChanged: (v) {
                      setState(() => _zooqleEnabled = v);
                      _config.enableZooqle = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Rutor',
                    description: 'Russian/International tracker',
                    value: _rutorEnabled,
                    leadingIcon: Icons.language,
                    onChanged: (v) {
                      setState(() => _rutorEnabled = v);
                      _config.enableRutor = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'The Pirate Bay',
                    description: 'Legacy tracker (ISP blocks common)',
                    value: _pirateBayEnabled,
                    leadingIcon: Icons.flag_circle,
                    isWarning: true,
                    onChanged: (v) {
                      setState(() => _pirateBayEnabled = v);
                      _config.enablePirateBay = v;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Indexers Section
            ExpandableSection(
              title: 'Indexers (Torznab)',
              icon: Icons.rss_feed_rounded,
              child: Column(
                children: [
                  SettingsToggle(
                    title: 'Enable Torznab',
                    description: 'Use custom Jackett/Prowlarr indexer',
                    value: _torznabEnabled,
                    leadingIcon: Icons.api_rounded,
                    onChanged: (v) {
                      setState(() => _torznabEnabled = v);
                      _config.enableTorznab = v;
                    },
                  ),
                  if (_torznabEnabled) ...[
                    const SizedBox(height: 12),
                    SettingsTextField(
                      controller: _torznabUrlController,
                      label: 'Torznab URL',
                      hint: 'http://localhost:9117/api/v2.0/indexers/.../api',
                      leadingIcon: Icons.link_rounded,
                      onChanged: (v) => _config.torznabUrl = v,
                    ),
                    const SizedBox(height: 12),
                    SettingsTextField(
                      controller: _torznabKeyController,
                      label: 'API Key',
                      hint: 'Indexer API Key',
                      obscureText: true,
                      leadingIcon: Icons.key_rounded,
                      onChanged: (v) => _config.setTorznabKey(v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Global Options Section
            ExpandableSection(
              title: 'Global Options',
              icon: Icons.settings_suggest_rounded,
              initiallyExpanded: true,
              child: Column(
                children: [
                  SettingsToggle(
                    title: 'Background Downloads',
                    description: 'Add to Debrid cloud instead of waiting',
                    value: _backgroundDownload,
                    leadingIcon: Icons.cloud_download_rounded,
                    onChanged: (v) {
                      setState(() => _backgroundDownload = v);
                      _config.backgroundDownload = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  SettingsToggle(
                    title: 'Debrid Failover',
                    description: 'Try secondary providers if primary fails',
                    value: _providerFailover,
                    leadingIcon: Icons.swap_calls_rounded,
                    onChanged: (v) {
                      setState(() => _providerFailover = v);
                      _config.providerFailover = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  SettingsTextField(
                    controller: _maxResultsProviderController,
                    label: 'Max Results Per Provider',
                    hint: '15',
                    leadingIcon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveInt(
                      _maxResultsProviderController,
                      (v) => _config.maxResultsPerProvider = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsToggle(
                    title: 'Direct Tracker Scraping',
                    description: 'Refresh seeder counts from UDP trackers',
                    value: _enableTrackerScraping,
                    leadingIcon: Icons.radar_rounded,
                    onChanged: (v) {
                      setState(() => _enableTrackerScraping = v);
                      _config.enableTrackerScraping = v;
                    },
                  ),
                  if (_enableTrackerScraping) ...[
                    const SizedBox(height: 12),
                    SettingsTextField(
                      controller: _trackerScrapeTimeoutController,
                      label: 'Scrape Timeout (ms)',
                      hint: '3000',
                      leadingIcon: Icons.timer_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _saveInt(
                        _trackerScrapeTimeoutController,
                        (v) => _config.trackerScrapeTimeoutMs = v,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

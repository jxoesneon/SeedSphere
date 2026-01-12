import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages and persists application-wide configurations.
///
/// Handles both secure items (API keys) and general preferences (filters, sorting).
class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;
  ConfigManager._internal();

  final _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // --- Playback Settings ---

  String get sortBy => _prefs.getString('pb_sort_by') ?? 'Resolution';
  set sortBy(String val) => _prefs.setString('pb_sort_by', val);

  String get maxResolution => _prefs.getString('pb_max_resolution') ?? '4k';
  set maxResolution(String val) => _prefs.setString('pb_max_resolution', val);

  bool get excludeCam => _prefs.getBool('pb_exclude_cam') ?? true;
  set excludeCam(bool val) => _prefs.setBool('pb_exclude_cam', val);

  bool get exclude3D => _prefs.getBool('pb_exclude_3d') ?? true;
  set exclude3D(bool val) => _prefs.setBool('pb_exclude_3d', val);

  bool get preferHDR => _prefs.getBool('pb_prefer_hdr') ?? true;
  set preferHDR(bool val) => _prefs.setBool('pb_prefer_hdr', val);

  String get includeRegex => _prefs.getString('pb_include_regex') ?? '';
  set includeRegex(String val) => _prefs.setString('pb_include_regex', val);

  String get excludeRegex => _prefs.getString('pb_exclude_regex') ?? '';
  set excludeRegex(String val) => _prefs.setString('pb_exclude_regex', val);

  bool get autoProxy => _prefs.getBool('pb_auto_proxy') ?? true;
  set autoProxy(bool val) => _prefs.setBool('pb_auto_proxy', val);

  int get maxTrackers => _prefs.getInt('pb_max_trackers') ?? 0;
  set maxTrackers(int val) => _prefs.setInt('pb_max_trackers', val);

  bool get probeTrackers => _prefs.getBool('pb_probe_trackers') ?? false;
  set probeTrackers(bool val) => _prefs.setBool('pb_probe_trackers', val);

  bool get preferEncrypted => _prefs.getBool('pb_prefer_encrypted') ?? false;
  set preferEncrypted(bool val) => _prefs.setBool('pb_prefer_encrypted', val);

  bool get normalizeHttps => _prefs.getBool('pb_normalize_https') ?? false;
  set normalizeHttps(bool val) => _prefs.setBool('pb_normalize_https', val);

  String get trackerVariant => _prefs.getString('pb_tracker_variant') ?? 'all';
  set trackerVariant(String val) => _prefs.setString('pb_tracker_variant', val);

  String get customTrackersUrl =>
      _prefs.getString('pb_custom_trackers_url') ?? '';
  set customTrackersUrl(String val) =>
      _prefs.setString('pb_custom_trackers_url', val);

  bool get backgroundDownload =>
      _prefs.getBool('pb_background_download') ?? false;
  set backgroundDownload(bool val) =>
      _prefs.setBool('pb_background_download', val);

  // --- Advanced Filtering (Gap Closure) ---

  bool get onlyShowCached => _prefs.getBool('pb_only_show_cached') ?? false;
  set onlyShowCached(bool val) => _prefs.setBool('pb_only_show_cached', val);

  /// Preferred source type. Options: 'Any', 'Blu-ray', 'WEB-DL', 'HDTV'.
  String get preferredSourceType => _prefs.getString('pb_source_pref') ?? 'Any';
  set preferredSourceType(String val) =>
      _prefs.setString('pb_source_pref', val);

  /// Comma-separated list of prioritized languages.
  List<String> get prioritizedLanguages =>
      (_prefs.getString('pb_prioritized_languages') ?? 'English')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  set prioritizedLanguages(List<String> val) =>
      _prefs.setString('pb_prioritized_languages', val.join(','));

  // --- Provider Toggles ---

  bool get enableTorrentio => _prefs.getBool('prov_torrentio') ?? true;
  set enableTorrentio(bool val) => _prefs.setBool('prov_torrentio', val);

  bool get enableYts => _prefs.getBool('prov_yts') ?? true;
  set enableYts(bool val) => _prefs.setBool('prov_yts', val);

  bool get enableEztv => _prefs.getBool('prov_eztv') ?? true;
  set enableEztv(bool val) => _prefs.setBool('prov_eztv', val);

  bool get enableNyaa => _prefs.getBool('prov_nyaa') ?? true;
  set enableNyaa(bool val) => _prefs.setBool('prov_nyaa', val);

  bool get enable1337x => _prefs.getBool('prov_1337x') ?? true;
  set enable1337x(bool val) => _prefs.setBool('prov_1337x', val);

  bool get enablePirateBay => _prefs.getBool('prov_piratebay') ?? true;
  set enablePirateBay(bool val) => _prefs.setBool('prov_piratebay', val);

  bool get enableTorrentGalaxy => _prefs.getBool('prov_torrentgalaxy') ?? true;
  set enableTorrentGalaxy(bool val) =>
      _prefs.setBool('prov_torrentgalaxy', val);

  bool get enableTorlock => _prefs.getBool('prov_torlock') ?? true;
  set enableTorlock(bool val) => _prefs.setBool('prov_torlock', val);

  bool get enableMagnetDL => _prefs.getBool('prov_magnetdl') ?? true;
  set enableMagnetDL(bool val) => _prefs.setBool('prov_magnetdl', val);

  bool get enableAniDex => _prefs.getBool('prov_anidex') ?? true;
  set enableAniDex(bool val) => _prefs.setBool('prov_anidex', val);

  bool get enableTokyoTosho => _prefs.getBool('prov_tokyotosho') ?? true;
  set enableTokyoTosho(bool val) => _prefs.setBool('prov_tokyotosho', val);

  bool get enableZooqle => _prefs.getBool('prov_zooqle') ?? true;
  set enableZooqle(bool val) => _prefs.setBool('prov_zooqle', val);

  bool get enableRutor => _prefs.getBool('prov_rutor') ?? true;
  set enableRutor(bool val) => _prefs.setBool('prov_rutor', val);

  /// Returns the number of enabled content providers out of the 13 built-in ones.
  int get activeProvidersCount {
    int count = 0;
    if (enableTorrentio) count++;
    if (enableYts) count++;
    if (enableEztv) count++;
    if (enableNyaa) count++;
    if (enable1337x) count++;
    if (enablePirateBay) count++;
    if (enableTorrentGalaxy) count++;
    if (enableTorlock) count++;
    if (enableMagnetDL) count++;
    if (enableAniDex) count++;
    if (enableTokyoTosho) count++;
    if (enableZooqle) count++;
    if (enableRutor) count++;
    return count;
  }

  // --- Optimization Settings ---

  String get validationMode =>
      _prefs.getString('opt_validation_mode') ?? 'basic';
  set validationMode(String val) =>
      _prefs.setString('opt_validation_mode', val);

  bool get probeProviders => _prefs.getBool('opt_probe_providers') ?? false;
  set probeProviders(bool val) => _prefs.setBool('opt_probe_providers', val);

  int get probeTimeoutMs => _prefs.getInt('opt_probe_timeout_ms') ?? 500;
  set probeTimeoutMs(int val) => _prefs.setInt('opt_probe_timeout_ms', val);

  int get providerFetchTimeoutMs =>
      _prefs.getInt('opt_prov_fetch_timeout_ms') ?? 5000;
  set providerFetchTimeoutMs(int val) =>
      _prefs.setInt('opt_prov_fetch_timeout_ms', val);

  int get maxResultsPerProvider => _prefs.getInt('opt_max_results_prov') ?? 15;
  set maxResultsPerProvider(int val) =>
      _prefs.setInt('opt_max_results_prov', val);

  bool get swarmEnabled => _prefs.getBool('p2p_scrape_swarm') ?? true;
  set swarmEnabled(bool val) => _prefs.setBool('p2p_scrape_swarm', val);

  int get swarmTopN => _prefs.getInt('p2p_swarm_top_n') ?? 20;
  set swarmTopN(int val) => _prefs.setInt('p2p_swarm_top_n', val);

  bool get autoBootstrap => _prefs.getBool('p2p_auto_bootstrap') ?? true;
  set autoBootstrap(bool val) => _prefs.setBool('p2p_auto_bootstrap', val);

  bool get enableLibp2pBridge =>
      _prefs.getBool('p2p_enable_libp2p_bridge') ?? true;
  set enableLibp2pBridge(bool val) =>
      _prefs.setBool('p2p_enable_libp2p_bridge', val);

  String get swarmKey =>
      _prefs.getString('p2p_swarm_key') ?? 'seedsphere-dev-swarm-2025';
  set swarmKey(String val) => _prefs.setString('p2p_swarm_key', val);

  bool get swarmMissingOnly => _prefs.getBool('opt_swarm_missing_only') ?? true;
  set swarmMissingOnly(bool val) =>
      _prefs.setBool('opt_swarm_missing_only', val);

  int get swarmTimeoutMs => _prefs.getInt('opt_swarm_timeout_ms') ?? 800;
  set swarmTimeoutMs(int val) => _prefs.setInt('opt_swarm_timeout_ms', val);

  bool get enableTrackerScraping =>
      _prefs.getBool('opt_enable_tracker_scrape') ?? true;
  set enableTrackerScraping(bool val) =>
      _prefs.setBool('opt_enable_tracker_scrape', val);

  int get trackerScrapeTimeoutMs =>
      _prefs.getInt('opt_tracker_scrape_timeout') ?? 3000;
  set trackerScrapeTimeoutMs(int val) =>
      _prefs.setInt('opt_tracker_scrape_timeout', val);

  // --- Torznab Settings ---

  bool get enableTorznab => _prefs.getBool('prov_torznab') ?? false;
  set enableTorznab(bool val) => _prefs.setBool('prov_torznab', val);

  String get torznabUrl => _prefs.getString('torznab_url') ?? '';
  set torznabUrl(String val) => _prefs.setString('torznab_url', val);

  Future<String?> getTorznabKey() =>
      _secureStorage.read(key: 'torznab_api_key');
  Future<void> setTorznabKey(String val) =>
      _secureStorage.write(key: 'torznab_api_key', value: val);

  // --- Description Settings ---

  bool get appendOriginalDesc =>
      _prefs.getBool('desc_append_original') ?? false;
  set appendOriginalDesc(bool val) =>
      _prefs.setBool('desc_append_original', val);

  bool get requireDetailsForOriginal =>
      _prefs.getBool('desc_require_details') ?? true;
  set requireDetailsForOriginal(bool val) =>
      _prefs.setBool('desc_require_details', val);

  bool get seriesTitleCleanup => _prefs.getBool('desc_series_cleanup') ?? true;
  set seriesTitleCleanup(bool val) =>
      _prefs.setBool('desc_series_cleanup', val);

  bool get providerFailover => _prefs.getBool('debrid_failover') ?? true;
  set providerFailover(bool val) => _prefs.setBool('debrid_failover', val);

  // --- Cortex (AI) Settings ---

  bool get neuroLinkEnabled => _prefs.getBool('cortex_enabled') ?? true;
  set neuroLinkEnabled(bool val) => _prefs.setBool('cortex_enabled', val);

  String get cortexProvider =>
      _prefs.getString('cortex_provider') ?? 'DeepSeek';
  set cortexProvider(String val) => _prefs.setString('cortex_provider', val);

  String get cortexModel => _prefs.getString('cortex_model') ?? 'deepseek-chat';
  set cortexModel(String val) => _prefs.setString('cortex_model', val);

  double get cortexDetailLevel => _prefs.getDouble('cortex_detail') ?? 1.0;
  set cortexDetailLevel(double val) => _prefs.setDouble('cortex_detail', val);

  int get aiTimeoutMs => _prefs.getInt('cortex_timeout_ms') ?? 2500;
  set aiTimeoutMs(int val) => _prefs.setInt('cortex_timeout_ms', val);

  int get aiCacheTtlMs => _prefs.getInt('cortex_cache_ttl_ms') ?? 60000;
  set aiCacheTtlMs(int val) => _prefs.setInt('cortex_cache_ttl_ms', val);

  String get aiUserId => _prefs.getString('cortex_user_id') ?? '';
  set aiUserId(String val) => _prefs.setString('cortex_user_id', val);

  // --- Azure AI Settings ---

  String get azureResource => _prefs.getString('cortex_azure_resource') ?? '';
  set azureResource(String val) =>
      _prefs.setString('cortex_azure_resource', val);

  String get azureDeployment => _prefs.getString('cortex_azure_deploy') ?? '';
  set azureDeployment(String val) =>
      _prefs.setString('cortex_azure_deploy', val);

  String get azureApiVersion =>
      _prefs.getString('cortex_azure_ver') ?? '2024-02-15-preview';
  set azureApiVersion(String val) => _prefs.setString('cortex_azure_ver', val);

  // --- Service Credentials Helpers ---

  String get orionUserId => _prefs.getString('orion_user_id') ?? '';
  set orionUserId(String val) => _prefs.setString('orion_user_id', val);

  Future<String?> getRealDebridToken() =>
      _secureStorage.read(key: 'rd_api_key');
  Future<void> setRealDebridToken(String val) =>
      _secureStorage.write(key: 'rd_api_key', value: val);

  Future<String?> getAllDebridApiKey() =>
      _secureStorage.read(key: 'ad_api_key');
  Future<void> setAllDebridApiKey(String val) =>
      _secureStorage.write(key: 'ad_api_key', value: val);

  Future<String?> getOrionApiKey() => _secureStorage.read(key: 'orion_api_key');
  Future<void> setOrionApiKey(String val) =>
      _secureStorage.write(key: 'orion_api_key', value: val);

  Future<String?> getPremiumizeApiKey() =>
      _secureStorage.read(key: 'premiumize_api_key');
  Future<void> setPremiumizeApiKey(String val) =>
      _secureStorage.write(key: 'premiumize_api_key', value: val);

  String get debridService =>
      _prefs.getString('debrid_service') ?? 'real_debrid';
  set debridService(String val) => _prefs.setString('debrid_service', val);

  Future<String?> getApiKey(String provider) async {
    return await _secureStorage.read(key: '${provider.toLowerCase()}_api_key');
  }

  Future<void> setApiKey(String provider, String key) async {
    await _secureStorage.write(
      key: '${provider.toLowerCase()}_api_key',
      value: key,
    );
  }
}

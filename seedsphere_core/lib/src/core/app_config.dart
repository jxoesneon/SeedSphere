/// Interface for application configuration required by core services.
abstract class AppConfig {
  /// The base URL for the Torznab indexer.
  String get torznabUrl;

  /// Retrieves the Torznab API key.
  Future<String?> getTorznabKey();

  /// Whether Torznab is enabled.
  bool get enableTorznab;

  /// The variant of the tracker list to use.
  String get trackerVariant;

  /// Custom URL for fetching the tracker list.
  String get customTrackersUrl;

  /// Whether to probe trackers for liveness.
  bool get probeTrackers;

  /// Whether to probe scraper providers for liveness.
  bool get probeProviders;

  /// Validation mode for probes ('aggressive' or 'basic').
  String get validationMode;

  /// Timeout in milliseconds for provider probes.
  int get probeTimeoutMs;

  /// Timeout in milliseconds for provider fetches.
  int get providerFetchTimeoutMs;

  /// Maximum number of results to return per provider.
  int get maxResultsPerProvider;

  /// Whether to enable direct UDP tracker scraping.
  bool get enableTrackerScraping;
}

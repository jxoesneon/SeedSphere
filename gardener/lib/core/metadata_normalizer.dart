/// Normalized stream/torrent metadata model.
///
/// Represents a single torrent or stream source with standardized fields
/// across different scraper providers (YTS, Torrentio, etc.).
class SeedStream {
  /// The display title of the stream (e.g., "Movie.2024.1080p.BluRay").
  final String title;

  /// The BitTorrent infohash (hex string) uniquely identifying the torrent.
  final String infoHash;

  /// Optional file index within the torrent (for multi-file torrents).
  final String? fileIdx;

  /// Standardized resolution string: '4K', '1080p', '720p', or 'SD'.
  final String resolution;

  /// The scraper source provider (e.g., 'YTS', 'Torrentio').
  final String source;

  /// Number of seeders for this torrent.
  final int seeders;

  /// Creates a new [SeedStream] instance.
  SeedStream({
    required this.title,
    required this.infoHash,
    this.fileIdx,
    required this.resolution,
    required this.source,
    required this.seeders,
  });

  /// Converts this stream to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'title': title,
    'infoHash': infoHash,
    if (fileIdx != null) 'fileIdx': fileIdx,
    'resolution': resolution,
    'source': source,
    'seeders': seeders,
  };
}

/// Utility for normalizing stream metadata from different scraper sources.
///
/// Different torrent/stream providers use varying field names and formats.
/// This normalizer standardizes them into a consistent [SeedStream] model.
///
/// Example:
/// ```dart
/// // Raw data from YTS scraper
/// final rawYTS = {'title': 'Movie.2024.2160p', 'hash': 'ABC123', 'seeds': 50};
/// final stream = MetadataNormalizer.normalize(rawYTS, 'YTS');
/// print(stream.resolution); // '4K'
///
/// // Raw data from Torrentio
/// final rawTorrentio = {'name': 'Movie.720p', 'infoHash': 'DEF456', 'seeders': 10};
/// final stream2 = MetadataNormalizer.normalize(rawTorrentio, 'Torrentio');
/// print(stream2.resolution); // '720p'
/// ```
class MetadataNormalizer {
  /// Normalizes raw scraper data into a [SeedStream] model.
  ///
  /// [raw] - The raw metadata map from a scraper (field names vary by source).
  /// [provider] - The name of the scraper provider (e.g., 'YTS', 'Torrentio').
  ///
  /// Returns a normalized [SeedStream] with standardized fields.
  ///
  /// **Field Mapping:**
  /// - Title: `raw['title']` or `raw['name']` or "Unknown Stream"
  /// - InfoHash: `raw['infoHash']` or `raw['hash']` or empty string
  /// - Resolution: Extracted from title string (see [_extractResolution])
  /// - Seeders: `raw['seeders']` or 0
  static SeedStream normalize(Map<String, dynamic> raw, String provider) {
    return SeedStream(
      title: raw['title'] ?? raw['name'] ?? 'Unknown Stream',
      infoHash: raw['infoHash'] ?? raw['hash'] ?? '',
      fileIdx: raw['fileIdx']?.toString(),
      resolution: _extractResolution(raw['title'] ?? ''),
      source: provider,
      seeders: raw['seeders'] ?? 0,
    );
  }

  /// Extracts standardized resolution from a title string.
  ///
  /// [title] - The stream/torrent title to parse.
  ///
  /// Returns one of: '4K', '1080p', '720p', or 'SD' (default).
  ///
  /// **Detection patterns (case-insensitive):**
  /// - **4K**: Contains '2160p', '4k', or 'uhd'
  /// - **1080p**: Contains '1080p'
  /// - **720p**: Contains '720p'
  /// - **SD**: Everything else (480p, no quality specified, etc.)
  static String _extractResolution(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('2160p') ||
        lower.contains('4k') ||
        lower.contains('uhd')) {
      return '4K';
    }
    if (lower.contains('1080p')) {
      return '1080p';
    }
    if (lower.contains('720p')) {
      return '720p';
    }
    return 'SD';
  }
}

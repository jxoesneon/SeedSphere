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

  /// Detected video codec (e.g., 'x265', 'x264', 'AV1').
  final String? codec;

  /// Detected audio format (e.g., 'Dolby Atmos', 'DDP 5.1').
  final String? audio;

  /// Detected HDR type (e.g., 'Dolby Vision', 'HDR10+').
  final String? hdr;

  /// Detected languages (e.g., ['en', 'es-419']).
  final List<String> languages;

  /// File size in bytes (if available).
  final int? sizeBytes;

  /// Creates a new [SeedStream] instance.
  SeedStream({
    required this.title,
    required this.infoHash,
    this.fileIdx,
    required this.resolution,
    required this.source,
    required this.seeders,
    this.codec,
    this.audio,
    this.hdr,
    this.languages = const [],
    this.sizeBytes,
  });

  /// Converts this stream to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'title': title,
    'infoHash': infoHash,
    if (fileIdx != null) 'fileIdx': fileIdx,
    'resolution': resolution,
    'source': source,
    'seeders': seeders,
    if (codec != null) 'codec': codec,
    if (audio != null) 'audio': audio,
    if (hdr != null) 'hdr': hdr,
    if (languages.isNotEmpty) 'languages': languages,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };
}

/// Utility for normalizing stream metadata from different scraper sources.
///
/// Ensures 1:1 parity with legacy `parse.cjs` logic by extracting:
/// - Resolution (4K, 1080p)
/// - Codec (HEVC, x264)
/// - HDR (Dolby Vision, HDR10+)
/// - Audio (Atmos, DDP, Surround)
/// - Languages (Multi-lingual detection)
class MetadataNormalizer {
  // Regex patterns from legacy `parse.cjs`
  static final _reHevc = RegExp(r'(hevc|x265|h\.265)', caseSensitive: false);
  static final _reAvc = RegExp(r'(x264|h\.264)', caseSensitive: false);
  static final _reAv1 = RegExp(r'av1', caseSensitive: false);

  static final _reHdrDv = RegExp(
    r'Dolby[ \-.]?Vision|\bDV\b',
    caseSensitive: false,
  );
  static final _reHdr10Plus = RegExp(r'HDR10\+?', caseSensitive: false);
  static final _reHdr = RegExp(r'\bHDR\b', caseSensitive: false);

  static final _reAudio = RegExp(
    r'(DDP(?:\.?5\.1)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|AAC|Opus)',
    caseSensitive: false,
  );

  static final _reSize = RegExp(
    r'(\d+(?:\.\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\b',
    caseSensitive: false,
  );

  /// Normalizes raw scraper data into a [SeedStream] model.
  static SeedStream normalize(Map<String, dynamic> raw, String provider) {
    final title = raw['title'] ?? raw['name'] ?? 'Unknown Stream';
    final lowerTitle = title.toLowerCase();

    // Use legacy logic for size parsing if not provided numerically
    int? sizeBytes = _parseInt(raw['sizeBytes'] ?? raw['size_bytes']);

    if (sizeBytes == null && raw['size'] is String) {
      sizeBytes = _parseSize(raw['size']);
    }

    sizeBytes ??= _parseSize(title); // Attempt to find size in title

    return SeedStream(
      title: title,
      infoHash: raw['infoHash'] ?? raw['hash'] ?? '',
      fileIdx: raw['fileIdx']?.toString(),
      resolution: _extractResolution(title),
      source: provider,
      seeders: _parseInt(raw['seeders']) ?? 0,
      codec: _extractCodec(lowerTitle),
      hdr: _extractHdr(lowerTitle),
      audio: _extractAudio(title),
      languages: _extractLanguages(lowerTitle),
      sizeBytes: sizeBytes,
    );
  }

  static String _extractResolution(String title) {
    final lower = title.toLowerCase();
    // Legacy mapping parity
    if (lower.contains('2160p') ||
        lower.contains('4k') ||
        lower.contains('uhd')) {
      return '4K';
    }
    if (lower.contains('1080p')) return '1080p';
    if (lower.contains('720p')) return '720p';
    if (lower.contains('480p')) return '480p';
    return 'SD';
  }

  static String? _extractCodec(String s) {
    if (_reHevc.hasMatch(s)) return 'HEVC x265';
    if (_reAvc.hasMatch(s)) return 'x264';
    if (_reAv1.hasMatch(s)) return 'AV1';
    return null;
  }

  static String? _extractHdr(String s) {
    if (_reHdr10Plus.hasMatch(s)) return 'HDR10+';
    if (_reHdrDv.hasMatch(s)) return 'Dolby Vision';
    if (_reHdr.hasMatch(s)) return 'HDR';
    return null;
  }

  static String? _extractAudio(String s) {
    // Audio regex is case-insensitive but we preserve formatting for display
    final match = _reAudio.firstMatch(s);
    if (match != null) {
      return match.group(1)!.replaceAll('_', ' ').toUpperCase();
    }
    return null;
  }

  static List<String> _extractLanguages(String s) {
    final Set<String> found = {};

    // Check against all aliases from StreamMappings
    // Note: Iterate over a flat list of checks for performance?
    // Legacy code did 17 if-checks. We can map that.

    // Parity with parse.cjs hardcoded checks
    if (s.contains('multi') || s.contains('dual')) found.add('Multi');

    // Common languages check
    // We iterate the alias map but optimized for key phrases in parse.cjs
    if (s.contains('eng') || s.contains('english')) found.add('en');
    if (s.contains('spa') || s.contains('latino') || s.contains('castellano')) {
      found.add('es');
    }
    if (s.contains('fre') || s.contains('french') || s.contains('vff')) {
      found.add('fr');
    }
    if (s.contains('ger') || s.contains('german') || s.contains('deutsch')) {
      found.add('de');
    }
    if (s.contains('ita') || s.contains('italian')) found.add('it');
    if (s.contains('rus') || s.contains('russian')) found.add('ru');
    if (s.contains('por') || s.contains('portuguese') || s.contains('brazil')) {
      found.add('pt');
    }
    if (s.contains('jpn') || s.contains('japanese')) found.add('ja');
    if (s.contains('kor') || s.contains('korean')) found.add('ko');
    if (s.contains('chi') || s.contains('chinese')) found.add('zh');
    if (s.contains('hin') || s.contains('hindi')) found.add('hi');

    return found.toList();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _parseSize(String s) {
    final match = _reSize.firstMatch(s);
    if (match == null) return null;

    try {
      final num = double.parse(match.group(1)!);
      final unit = match.group(2)!.toUpperCase();

      int mult = 1024;
      if (unit.startsWith('T')) {
        mult = 1024 * 1024 * 1024 * 1024;
      } else if (unit.startsWith('G')) {
        mult = 1024 * 1024 * 1024;
      } else if (unit.startsWith('M')) {
        mult = 1024 * 1024;
      }

      return (num * mult).round();
    } catch (_) {
      return null;
    }
  }
}

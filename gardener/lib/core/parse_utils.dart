/// Port of legacy/server/lib/parse.cjs
class ParseUtils {
  /// Cleans a release title by removing dots, underscores, and common tags.
  static String cleanTitle(String title) {
    if (title.isEmpty) return '';
    var t = title.replaceAll(RegExp(r'[._]'), ' ');
    // Remove year, resolution, etc if they appear at the end or in middle
    t = t
        .split(
          RegExp(
            r'\b(2160p|1080p|720p|480p|4k|uhd|bluray|web-dl|webrip|h\.?26[45]|x26[45]|av1|19[0-9]{2}|20[0-9]{2})\b',
            caseSensitive: false,
          ),
        )
        .first;
    // Remove trailing dashes/brackets
    t = t.trim().replaceAll(RegExp(r'[-–]$'), '').trim();
    return t;
  }

  /// Extracts just the Show Name from a series release title.
  static String cleanShowName(String title) {
    var t = title.replaceAll(RegExp(r'[._]'), ' ');
    // Cut off at Sxx or SxxExx
    final match = RegExp(
      r'\bS(\d{1,2})(?:E(\d{1,2}))?\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (match != null) {
      t = t.substring(0, match.start);
    }
    // Cut off at year
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(t);
    if (yearMatch != null) {
      t = t.substring(0, yearMatch.start);
    }
    return t.trim();
  }

  /// Extracts name from magnet link.
  static String getMagnetName(String magnet) {
    if (!magnet.startsWith('magnet:?')) return '';
    try {
      // Uri.parse handles decoding query parameters automatically in queryParameters
      // But magnet URIs are tricky.
      // Let's use simple string parsing like legacy to be safe or Uri.splitQueryString
      final qs = magnet.substring(8);
      final params = Uri.splitQueryString(qs);
      return params['dn'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Parses Stremio-style ID (tt123:1:1) into season/episode.
  static Map<String, int>? parseSeriesId(String rawId) {
    final parts = rawId.split(':');
    if (parts.length >= 3) {
      final season = int.tryParse(parts[1]);
      final episode = int.tryParse(parts[2]);
      if (season != null && episode != null) {
        return {'season': season, 'episode': episode};
      }
    }
    return null;
  }

  /// Extracts Season and Episode from a title string.
  static Map<String, int>? extractSeasonEpisode(String rawTitle) {
    final norm = rawTitle.replaceAll(RegExp(r'[._]+'), ' ');
    final m = RegExp(
      r'\bS(\d{1,2})E(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(norm);
    if (m != null) {
      final season = int.tryParse(m.group(1)!);
      final episode = int.tryParse(m.group(2)!);
      if (season != null && episode != null) {
        return {'season': season, 'episode': episode};
      }
    }
    return null;
  }

  /// Extracts year from title.
  static int? extractYear(String title) {
    final m = RegExp(r'\b(19|20)\d{2}\b').firstMatch(title);
    if (m != null) {
      return int.tryParse(m.group(0)!);
    }
    return null;
  }

  static String normalizeCodec(String s) {
    final x = s.toLowerCase();
    if (RegExp(r'(hevc|x265|h\.265)').hasMatch(x)) return 'HEVC x265';
    if (RegExp(r'(x264|h\.264)').hasMatch(x)) return 'x264';
    if (RegExp(r'av1').hasMatch(x)) return 'AV1';
    return s;
  }

  static Map<String, dynamic> parseSize(String str) {
    try {
      final m = RegExp(
        r'(\d+(?:\.\d+)?)\s*(TB|TiB|GB|GiB|MB|MiB|KB|KiB)\b',
        caseSensitive: false,
      ).firstMatch(str);
      if (m == null) return {'sizeStr': null, 'sizeBytes': null};

      final numVal = double.parse(m.group(1)!);
      final unit = m.group(2)!.toUpperCase();

      num mult = 1024;
      if (unit == 'TB' || unit == 'TIB') {
        mult = 1024 * 1024 * 1024 * 1024;
      } else if (unit == 'GB' || unit == 'GIB') {
        mult = 1024 * 1024 * 1024;
      } else if (unit == 'MB' || unit == 'MIB') {
        mult = 1024 * 1024;
      }

      final sizeBytes = (numVal * mult).round();
      final sizeStr = '$numVal ${unit.replaceAll('IB', 'B')}';

      return {'sizeStr': sizeStr, 'sizeBytes': sizeBytes};
    } catch (_) {
      return {'sizeStr': null, 'sizeBytes': null};
    }
  }

  static List<String> parseLanguages(String str) {
    final s = str.toLowerCase();
    final langs = <String>{};

    // Simple regex checks from legacy
    if (RegExp(r'\b(multi|multi[-_. ]lang|multi[-_. ]audio)\b').hasMatch(s)) {
      langs.add('Multi');
    }
    if (RegExp(r'\bdual\b').hasMatch(s)) langs.add('Dual');
    if (RegExp(r'\b(eng|english)\b').hasMatch(s)) langs.add('English');
    // ... complete list could be long, adding key ones
    if (RegExp(r'\b(spa|spanish|español|latino|castellano)\b').hasMatch(s)) {
      langs.add('Spanish');
    }
    if (RegExp(r'\b(fre|fra|french|francais|français)\b').hasMatch(s)) {
      langs.add('French');
    }
    if (RegExp(r'\b(ita|italian|italiano)\b').hasMatch(s)) langs.add('Italian');
    if (RegExp(r'\b(ger|deu|german|deutsch)\b').hasMatch(s)) {
      langs.add('German');
    }
    if (RegExp(r'\b(ru|rus|russian|русский)\b').hasMatch(s)) {
      langs.add('Russian');
    }
    if (RegExp(r'\b(pt|por|portuguese|português|brazil|br)\b').hasMatch(s)) {
      langs.add('Portuguese');
    }
    if (RegExp(r'\b(jpn|jp|japanese|日本語)\b').hasMatch(s)) langs.add('Japanese');
    if (RegExp(r'\b(kor|ko|korean|한국어)\b').hasMatch(s)) langs.add('Korean');
    if (RegExp(r'\b(chi|zho|chinese|中文|国配|國語)\b').hasMatch(s)) {
      langs.add('Chinese');
    }

    return langs.toList();
  }

  static Map<String, dynamic> parseReleaseInfo(
    String magnet, [
    String fallbackTitle = '',
  ]) {
    final name = (getMagnetName(magnet).isNotEmpty
        ? getMagnetName(magnet)
        : fallbackTitle);
    final out = <String, dynamic>{
      'name': name,
      'resolution': null,
      'source': null,
      'codec': null,
      'hdr': null,
      'audio': null,
      'group': null,
      'sizeStr': null,
      'sizeBytes': null,
      'languages': <String>[],
    };

    final s = name;

    // Resolution
    final resMatch = RegExp(
      r'(2160p|1080p|720p|480p|4k|uhd)',
      caseSensitive: false,
    ).firstMatch(s);
    if (resMatch != null) {
      final r = resMatch.group(1)!.toLowerCase();
      if (r == '4k' || r == 'uhd') {
        out['resolution'] = '2160P';
      } else {
        out['resolution'] = r.toUpperCase();
      }
    }

    // Source
    final srcMatch = RegExp(
      r'(WEB[-_. ]?DL|WEB[-_. ]?Rip|BluRay|BDRip|BRRip|HDRip|DVDRip)',
      caseSensitive: false,
    ).firstMatch(s);
    if (srcMatch != null) {
      out['source'] = srcMatch
          .group(1)!
          .replaceAll(RegExp(r'[_.]'), '')
          .toUpperCase();
    }

    // Codec
    final codecMatch = RegExp(
      r'(HEVC|x265|H\.265|x264|H\.264|AV1)',
      caseSensitive: false,
    ).firstMatch(s);
    if (codecMatch != null) {
      out['codec'] = normalizeCodec(codecMatch.group(1)!);
    }

    // HDR
    if (RegExp(r'HDR10\+?', caseSensitive: false).hasMatch(s)) {
      out['hdr'] = 'HDR10+';
    } else if (RegExp(
      r'Dolby[ \-.]?Vision|\bDV\b',
      caseSensitive: false,
    ).hasMatch(s)) {
      out['hdr'] = 'Dolby Vision';
    } else if (RegExp(r'\bHDR\b', caseSensitive: false).hasMatch(s)) {
      out['hdr'] = 'HDR';
    }

    // Audio
    final audioMatch = RegExp(
      r'(DDP(?:\.?5\.1)?|E-?AC-?3|AC3|DTS(?:-HD)?(?: MA)?|TrueHD|AAC|Opus)',
      caseSensitive: false,
    ).firstMatch(s);
    if (audioMatch != null) {
      out['audio'] = audioMatch.group(1)!.replaceAll('_', ' ').toUpperCase();
    }

    // Group
    final groupDash = RegExp(
      r'-(\w+)(?:\.[a-z0-9]+)?$',
      caseSensitive: false,
    ).firstMatch(s);
    final groupBrk = RegExp(r'\[(\w+)\]$', caseSensitive: false).firstMatch(s);
    out['group'] = groupBrk?.group(1) ?? groupDash?.group(1);

    // Size
    final sizeData = parseSize(s);
    out['sizeStr'] = sizeData['sizeStr'];
    out['sizeBytes'] = sizeData['sizeBytes'];

    // Languages
    out['languages'] = parseLanguages(s);

    return out;
  }
}

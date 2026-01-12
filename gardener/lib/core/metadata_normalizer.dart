import 'package:gardener/core/mapping_constants.dart';
import 'package:gardener/core/parse_utils.dart';

/// Normalize metadata using mapping constants.
/// Port of legacy/server/lib/normalize.cjs
class MetadataNormalizer {
  static String toTitleNatural(String title) {
    var t = title;
    // Remove (YYYY)
    t = t.replaceAll(RegExp(r'\(\s*(19|20)\d{2}\s*\)'), '').trim();
    // Remove [Remastered ...] brackets
    t = t
        .replaceAll(
          RegExp(r'\[\s*Remaster(?:ed)?[^\]]*\]', caseSensitive: false),
          '',
        )
        .trim();
    // Remove trailing edition segments
    t = t
        .replaceAll(
          RegExp(
            r'[\s]*[\u2014\-:][\s]*(Director(?:’|\x27)s Cut|Extended(?: Edition)?|Ultimate(?: Edition)?|Theatrical(?: Cut)?|Unrated|IMAX|Special(?: Edition)?)(?:.*)?$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    // Remove trailing quality
    t = t
        .replaceAll(
          RegExp(
            r'\[?\b(2160p|1080p|720p|480p|4k)\b\]?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    // Collapse spaces
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static int? extractYear(String title) {
    final mParen = RegExp(r'\((19|20)\d{2}\)').firstMatch(title);
    if (mParen != null) {
      return int.parse(mParen.group(0)!.substring(1, 5));
    }
    final mTrail = RegExp(
      r'(?:^|[^0-9])(19|20)\d{2}(?!.*(19|20)\d{2})',
    ).firstMatch(title);
    if (mTrail != null) {
      final y = RegExp(r'(19|20)\d{2}').firstMatch(mTrail.group(0)!)?.group(0);
      if (y != null) return int.parse(y);
    }
    return null;
  }

  static String? mapEdition(String title) {
    final s = title.toLowerCase();
    for (final canon in MappingConstants.editionCanonical) {
      final aliases = MappingConstants.editionAliases[canon] ?? [];
      for (final a in aliases) {
        // Check for boundary or start/end
        // Dart RegExp escaping is manual, simplify:
        if (s.contains(a)) {
          // crude check, but mirrors legacy roughly
          return canon;
        }
      }
    }
    return null;
  }

  static Map<String, String?>? extractRemaster(String title) {
    final br = RegExp(
      r'\[\s*Remaster(?:ed)?\s*([^\]]*)\]',
      caseSensitive: false,
    ).firstMatch(title);
    if (br != null) {
      return {'flag': 'true', 'note': br.group(1)?.trim()};
    }
    final suf = RegExp(
      r'Remaster(?:ed)?\s*(4K|1080p|2160p|HDR10\+?|DV|Dolby Vision)?',
      caseSensitive: false,
    ).firstMatch(title);
    if (suf != null) {
      return {'flag': 'true', 'note': suf.group(1)?.toUpperCase()};
    }
    return null;
  }

  static String? extractVersionTag(String extras, String title) {
    final sources = [extras, title];
    for (final src in sources) {
      for (final pat in MappingConstants.versionTagPatterns) {
        final m = RegExp(pat, caseSensitive: false).firstMatch(src);
        if (m != null) return m.group(0);
      }
    }
    return null;
  }

  static String? mapQuality(String q) {
    final s = q.toLowerCase();
    // direct
    for (final canon in MappingConstants.qualityCanonical) {
      if (canon.toLowerCase() == s) return canon;
    }
    // alias
    for (final canon in MappingConstants.qualityCanonical) {
      final aliases = MappingConstants.qualityAliases[canon] ?? [];
      for (final a in aliases) {
        if (a.toLowerCase() == s) return canon;
      }
    }
    // tolerant
    if (RegExp(r'\b4k\b|2160').hasMatch(s)) return '2160p';
    if (s.contains('1080')) return '1080p';
    if (s.contains('720')) return '720p';
    if (s.contains('480')) return '480p';
    return null;
  }

  static Map<String, dynamic> expandLanguages(dynamic input) {
    List<String> items = [];
    if (input is List) {
      items = input.map((e) => e.toString()).toList();
    } else if (input is String) {
      items = input.split(RegExp(r'[,;\s]+'));
    }

    final displays = <String>[];
    final flags = <String>[];
    final codes = <String>[];

    final langIndex = {
      for (var l in MappingConstants.languages) l['code']!.toLowerCase(): l,
    };

    for (var raw in items) {
      raw = raw.trim();
      if (raw.isEmpty) continue;
      final low = raw.toLowerCase();

      // Multi special
      final multis = MappingConstants.languageAliases['multi']!;
      if (multis.any((m) => m.toLowerCase() == low)) continue;

      String? code;
      MappingConstants.languageAliases.forEach((canon, aliases) {
        if (canon == 'multi') return;
        if (canon.toLowerCase() == low ||
            aliases.any((a) => a.toLowerCase() == low)) {
          code = canon;
        }
      });
      code ??= raw; // Fallback to raw

      codes.add(code!);
      final rec = langIndex[code!.toLowerCase()];
      if (rec != null) {
        displays.add(rec['display']!);
        flags.add(rec['flag']!);
      } else {
        // Unknown logic
        displays.add(code!);
        flags.add('🌐');
      }
    }

    if (displays.isEmpty) {
      return {
        'languages_display':
            MappingConstants.languagePolicy['unspecified_display'],
        'languages_flags': MappingConstants.languagePolicy['unspecified_flags'],
        'internal_codes': <String>[],
      };
    }

    return {
      'languages_display': displays,
      'languages_flags': flags,
      'internal_codes': codes,
    };
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> input) {
    final title = input['title']?.toString() ?? '';
    final providerIn = input['provider']?.toString() ?? '';
    final qualityIn =
        input['quality']?.toString() ?? (input['extras']?.toString() ?? '');
    final languageIn = input['language'] ?? input['languages'] ?? [];
    final infohashIn = input['infohash']?.toString() ?? '';
    final extrasIn = input['extras']?.toString() ?? '';

    final titleNatural = toTitleNatural(title);
    final year = extractYear(title);
    final edition = mapEdition(title);
    final remaster = extractRemaster(title);
    final versionTag = extractVersionTag(extrasIn, title);
    var quality = mapQuality(qualityIn);

    // Prov mapping simplified: just pass through
    final provDisplay = providerIn;

    final langData = expandLanguages(languageIn);

    final parsed = ParseUtils.parseReleaseInfo(extrasIn, title);

    if (quality == null && parsed['resolution'] != null) {
      quality = mapQuality(parsed['resolution']);
    }

    String? infohash;
    if (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(infohashIn.trim())) {
      infohash = infohashIn.trim().toUpperCase();
    }

    return {
      'title_natural': titleNatural,
      'year': year,
      'edition': edition,
      'remaster': remaster,
      'version_tag': versionTag,
      'quality': quality,
      'languages_display': langData['languages_display'],
      'languages_flags': langData['languages_flags'],
      'provider_display': provDisplay,
      'infohash': infohash,
      'extras': {
        'source': parsed['source'],
        'codec': parsed['codec'],
        'hdr': parsed['hdr'],
        'audio': parsed['audio'],
        'group': parsed['group'],
        'sizeStr': parsed['sizeStr'],
        'sizeBytes': parsed['sizeBytes'],
      },
      'internal': {'language_codes': langData['internal_codes']},
    };
  }
}

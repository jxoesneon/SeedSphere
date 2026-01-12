/// Port of legacy/server/lib/magnet.cjs
///
/// Provides utilities for magnet link handling:
/// - Safe normalization (stripping duplicates, cleaning query params)
/// - Tracker injection (appendTrackers) preserving "xt" exact format
/// - Construction (buildMagnet)
class MagnetUtils {
  /// Sanitizes query string to fix common encoding issues.
  /// Port of `sanitizeQuery`.
  static String sanitizeQuery(String qs) {
    if (qs.isEmpty) return '';
    return qs
        .replaceAll(RegExp(r'&amp;|&amp%3B', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&&+'), '&');
  }

  /// Normalizes a magnet link.
  /// Drops tracker params to dedupe on base (xt + dn).
  static String normalizeMagnet(String magnet) {
    try {
      final s = magnet.trim();
      if (!s.startsWith('magnet:?')) return '';
      final q = sanitizeQuery(s.substring(8));

      // We manually parse to avoid decoding 'xt' values which might be sensitive to case/colon
      // But standard Uri.splitQueryString decodes.
      // Replicating legacy: split by &, filter tr=
      final parts = q
          .split('&')
          .where((kv) => kv.isNotEmpty && !kv.startsWith('tr='));
      return 'magnet:?${parts.join('&')}';
    } catch (_) {
      return '';
    }
  }

  /// Helper to serialize magnet params while keeping `xt` raw.
  static String serializeMagnetParams(Map<String, List<String>> params) {
    final parts = <String>[];

    // xt first, raw
    if (params.containsKey('xt')) {
      for (final xt in params['xt']!) {
        parts.add('xt=$xt');
      }
    }

    // dn second, encoded
    if (params.containsKey('dn')) {
      for (final dn in params['dn']!) {
        parts.add('dn=${Uri.encodeComponent(dn)}');
      }
    }

    // tr third, encoded
    if (params.containsKey('tr')) {
      for (final tr in params['tr']!) {
        if (tr.isEmpty) continue;
        parts.add('tr=${Uri.encodeComponent(tr)}');
      }
    }

    // others
    params.forEach((k, values) {
      if (k == 'xt' || k == 'dn' || k == 'tr') return;
      for (final v in values) {
        parts.add('${Uri.encodeComponent(k)}=${Uri.encodeComponent(v)}');
      }
    });

    return 'magnet:?${parts.join('&')}';
  }

  /// Appends [trackers] to [magnet], dedoubling against existing ones.
  static String appendTrackers(String magnet, List<String> trackers) {
    try {
      final base = magnet.trim();
      if (!base.startsWith('magnet:?')) return base;

      final qs = sanitizeQuery(base.substring(8));

      // Manually parse to preserve order/raw-ness of XT
      final Map<String, List<String>> currentParams = {};
      final rawParts = qs.split('&');

      for (final part in rawParts) {
        if (part.isEmpty) continue;
        final eqIdx = part.indexOf('=');
        if (eqIdx == -1) continue;
        final key = part.substring(0, eqIdx);
        // We decode value lightly, but legacy keeps xt raw.
        // Let's decode value for comparison (seen set) but if it's XT store raw?
        // Legacy: "params = new URLSearchParams(...)" then "xt = params.get('xt')" (decoded)
        // BUT legacy serialize: "parts.push(`xt=${String(xt)}`)"

        // Actually legacy normalizeMagnet drops tr params.
        // appendTrackers reads tr from URLSearchParams, adds them to 'seen', adds new ones.

        final valRaw = part.substring(eqIdx + 1);
        final valDecoded = Uri.decodeComponent(valRaw);

        if (!currentParams.containsKey(key)) {
          currentParams[key] = [];
        }

        // XT special handling in legacy was to AVOID encoding ':' in "urn:btih:..."
        // Because encodeURIComponent turns ':' into '%3A' which some clients dislike.
        if (key == 'xt') {
          // Store RAW value for XT to avoid re-encoding issues
          currentParams[key]!.add(valRaw);
        } else {
          currentParams[key]!.add(valDecoded);
        }
      }

      final seen = <String>{};
      if (currentParams.containsKey('tr')) {
        seen.addAll(currentParams['tr']!);
      } else {
        currentParams['tr'] = [];
      }

      for (final t in trackers) {
        if (t.isEmpty || seen.contains(t)) continue;
        currentParams['tr']!.add(t);
        seen.add(t);
      }

      return serializeMagnetParams(currentParams);
    } catch (_) {
      return magnet;
    }
  }

  static String buildMagnet(
    String infoHash,
    String? name,
    List<String> trackers,
  ) {
    try {
      final hash = infoHash.trim();
      if (hash.isEmpty) return '';

      final Map<String, List<String>> params = {};
      // Legacy: "urn:btih:${hash}" -- do not encode ':'
      params['xt'] = ['urn:btih:$hash'];

      if (name != null) {
        params['dn'] = [name];
      }

      final trList = <String>[];
      final set = <String>{};

      for (final t in trackers) {
        if (t.isEmpty || set.contains(t)) continue;
        set.add(t);
        trList.add(t);
      }
      params['tr'] = trList;

      return serializeMagnetParams(params);
    } catch (_) {
      return '';
    }
  }

  /// Helper to get infohash from magnet for deduplication
  static String? getInfoHash(String magnet) {
    try {
      final s = magnet.trim();
      if (!s.startsWith('magnet:?')) return null;
      final qs = s.substring(8);
      final parts = qs.split('&');
      for (final p in parts) {
        if (p.startsWith('xt=urn:btih:')) {
          return p.substring(12).toLowerCase(); // 12 = len('xt=urn:btih:')
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

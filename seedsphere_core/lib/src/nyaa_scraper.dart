import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scraper_engine.dart';

/// Scraper implementation for the Nyaa provider (Anime).
class NyaaScraper extends BaseScraper {
  final http.Client _client;

  /// Creates a new NyaaScraper.
  NyaaScraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: 'Nyaa', baseUrl: 'https://nyaa.si');

  @override
  Future<List<Map<String, dynamic>>> scrape(
    String imdbId, {
    Function(String)? onLog,
  }) async {
    try {
      final metaInfo = await _fetchCinemetaTitle(
        imdbId.startsWith('tt') ? 'movie' : 'series',
        imdbId,
      );
      if (metaInfo == null) return [];

      final query = Uri.encodeComponent(metaInfo['title']);
      // final type = imdbId.startsWith('tt') ? 'movie' : 'series';
      // final year = int.tryParse(metaInfo['year'].toString());

      final url = '$baseUrl/?f=0&c=0_0&q=$query';

      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final results = _parseResults(response.body);

      return results.take(40).map((res) {
        final hash = _extractInfoHash(res.magnet);
        final dn = _extractMagnetDN(res.magnet);
        final cleanDn = dn != null ? Uri.decodeComponent(dn).replaceAll('+', ' ') : metaInfo['title'];

        return {
          'title': cleanDn ?? 'Unknown',
          'infoHash': hash,
          'magnet': res.magnet,
          'provider': 'Nyaa',
          'seeders': res.seeders,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<({String magnet, int seeders})> _parseResults(String html) {
    final results = <({String magnet, int seeders})>[];
    
    // Nyaa table rows
    final rows = html.split('<tr');
    for (final row in rows) {
      // 1. Extract Magnet
      final magnetMatch = RegExp(
        r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
        caseSensitive: false,
      ).firstMatch(row);
      if (magnetMatch == null) continue;
      final magnet = magnetMatch.group(1)!;

      // 2. Extract Seeders
      // <td class="text-center">123</td> (Seeders is usually the 2nd to last cell)
      final seederMatches = RegExp(r'<td class="text-center">(\d+)</td>').allMatches(row);
      int seeders = 0;
      if (seederMatches.isNotEmpty) {
        // Nyaa structure: [Size, Date, Seeders, Leechers, Completed]
        // Usually Seeders is the 3rd match in this specific row-segment
        if (seederMatches.length >= 3) {
          seeders = int.tryParse(seederMatches.elementAt(seederMatches.length - 3).group(1)!) ?? 0;
        }
      }

      results.add((magnet: magnet, seeders: seeders));
    }

    return results;
  }

  String? _extractInfoHash(String magnetUrl) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetUrl);
    return match?.group(1)?.toLowerCase();
  }

  String? _extractMagnetDN(String magnetUrl) {
    final match = RegExp(r'dn=([^&]+)').firstMatch(magnetUrl);
    return match?.group(1);
  }

  Future<Map<String, dynamic>?> _fetchCinemetaTitle(
    String type,
    String id,
  ) async {
    try {
      final url = 'https://v3-cinemeta.strem.io/meta/$type/$id.json';
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meta = data['meta'] as Map<String, dynamic>?;

      if (meta == null) return null;

      return {
        'title': meta['name'] ?? meta['title'] ?? '',
        'year': meta['year'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }
}

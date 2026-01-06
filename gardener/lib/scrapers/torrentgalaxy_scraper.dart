import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';

/// Scraper implementation for TorrentGalaxy.
class TorrentGalaxyScraper extends BaseScraper {
  static const List<String> mirrors = [
    'https://torrentgalaxy.mx',
    'https://torrentgalaxy.to',
    'https://tgx.rs',
  ];
  static String get defaultBase => mirrors[0];

  final http.Client _client;

  TorrentGalaxyScraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: 'TorrentGalaxy', baseUrl: defaultBase);

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    try {
      final type = imdbId.contains('tt') ? 'series' : 'movie';
      final metaInfo = await _fetchCinemetaTitle(type, imdbId);
      if (metaInfo == null) return [];

      final searchQuery = Uri.encodeComponent(metaInfo['title'] as String);
      final url =
          '$defaultBase/torrents.php?search=$searchQuery&sort=seeders&order=desc';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final magnets = _parseMagnetsFromHtml(response.body);

      return magnets.take(40).map((magnetUrl) {
        return {
          'title': metaInfo['title'] ?? 'TorrentGalaxy',
          'infoHash': _extractInfoHash(magnetUrl),
          'magnetUrl': magnetUrl,
          'provider': 'TorrentGalaxy',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Common helper methods duplicate across scrapers for independence
  // In a real refactor we'd move these to a mixin
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
      final data = jsonDecode(response.body);
      return data['meta'] != null ? {'title': data['meta']['name']} : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _parseMagnetsFromHtml(String html) {
    final magnets = <String>{};
    final regex = RegExp(
      r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
      caseSensitive: false,
    );
    for (final match in regex.allMatches(html)) {
      if (match.group(1) != null) magnets.add(match.group(1)!);
    }
    return magnets.toList();
  }

  String? _extractInfoHash(String magnetUrl) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetUrl);
    return match?.group(1)?.toLowerCase();
  }
}

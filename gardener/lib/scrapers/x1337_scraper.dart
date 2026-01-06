import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';

/// Scraper implementation for the 1337x provider (General).
class X1337Scraper extends BaseScraper {
  static const List<String> mirrors = [
    'https://www.1377x.to',
    'https://www.1337x.to',
    'https://1337x.to',
  ];

  static String get defaultBase => mirrors[0];

  final http.Client _client;

  X1337Scraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: '1337x', baseUrl: defaultBase);

  Map<String, String> _makeHeaders() => {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    try {
      // 1. Fetch metadata title from Cinemeta to get query
      // Similar reasoning as Nyaa, 1337x needs text query.
      // We try series then movie if ID type unknown, or infer.
      final type = imdbId.contains('tt') ? 'series' : 'movie';

      // Try to fetch cinemeta title
      var metaInfo = await _fetchCinemetaTitle(type, imdbId);
      if (metaInfo == null && type == 'series') {
        // Fallback to movie if series failed (though 'tt' usually means both)
        metaInfo = await _fetchCinemetaTitle('movie', imdbId);
      }

      if (metaInfo == null) return [];

      final searchQuery = Uri.encodeComponent(metaInfo['title'] as String);
      final url = '$defaultBase/search/$searchQuery/1/';

      final response = await _client
          .get(Uri.parse(url), headers: _makeHeaders())
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      // Extract detail page links
      final detailLinks = _extractDetailLinks(response.body).take(5).toList();

      // Fetch detail pages in parallel
      final pages = await Future.wait(
        detailLinks.map((link) async {
          try {
            final detailResponse = await _client
                .get(Uri.parse('$defaultBase$link'), headers: _makeHeaders())
                .timeout(const Duration(seconds: 4));
            return detailResponse.statusCode == 200 ? detailResponse.body : '';
          } catch (_) {
            return '';
          }
        }),
      );

      // Parse magnets from all pages
      final magnets = pages
          .expand((html) => _parseMagnetsFromHtml(html))
          .take(30)
          .toList();

      return magnets.map((magnetUrl) {
        final hash = _extractInfoHash(magnetUrl);
        return {
          'title': metaInfo!['title'] ?? '1337x',
          'infoHash': hash,
          'magnetUrl': magnetUrl,
          'provider': '1337x',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _extractDetailLinks(String html) {
    final links = <String>{};
    final regex = RegExp(r'href="(/torrent/[^"]+)"');

    for (final match in regex.allMatches(html)) {
      final link = match.group(1);
      if (link != null) links.add(link);
    }

    return links.toList();
  }

  List<String> _parseMagnetsFromHtml(String html) {
    final magnets = <String>{};
    final regex = RegExp(
      r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
      caseSensitive: false,
    );

    for (final match in regex.allMatches(html)) {
      final magnetUrl = match.group(1);
      if (magnetUrl != null && magnetUrl.startsWith('magnet:?')) {
        magnets.add(magnetUrl);
      }
    }

    return magnets.toList();
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

  String? _extractInfoHash(String magnetUrl) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetUrl);
    return match?.group(1)?.toLowerCase();
  }
}

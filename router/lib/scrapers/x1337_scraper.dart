import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/scraper_engine.dart';
import 'package:router/core/title_verifier.dart';

/// Scraper implementation for the 1337x provider (General).
class X1337Scraper extends BaseScraper {
  /// List of mirrors for the 1337x website.
  static const List<String> mirrors = [
    'https://www.1377x.to',
    'https://www.1337x.to',
    'https://1337x.to',
  ];

  /// Returns the default base URL from the list of mirrors.
  static String get defaultBase => mirrors[0];

  final http.Client _client;

  /// Creates a new X1337Scraper.
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
      final type = imdbId.contains('tt') ? 'series' : 'movie';
      var metaInfo = await _fetchCinemetaTitle(type, imdbId);
      if (metaInfo == null && type == 'series') {
        metaInfo = await _fetchCinemetaTitle('movie', imdbId);
      }

      if (metaInfo == null) return [];
      final requestedTitle = metaInfo['title'] as String;
      final requestedYear = int.tryParse(metaInfo['year'].toString());

      final searchQuery = Uri.encodeComponent(requestedTitle);
      final url = '$defaultBase/search/$searchQuery/1/';

      final response = await _client
          .get(Uri.parse(url), headers: _makeHeaders())
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      // Extract detail page links AND titles
      final candidates = _extractCandidates(response.body);

      // Filter candidates using TitleVerifier BEFORE fetching details
      // This saves bandwidth/time and ensures quality.
      final verifiedCandidates = candidates
          .where((c) {
            return TitleVerifier.verify(
              requestedTitle,
              c.title,
              year: requestedYear,
            );
          })
          .take(5)
          .toList();

      if (verifiedCandidates.isEmpty) return [];

      // Fetch detail pages in parallel
      final results = await Future.wait(
        verifiedCandidates.map((c) async {
          try {
            final detailResponse = await _client
                .get(Uri.parse('$defaultBase${c.url}'), headers: _makeHeaders())
                .timeout(const Duration(seconds: 4));

            if (detailResponse.statusCode != 200) return null;

            final magnetUrl = _extractMagnet(detailResponse.body);
            if (magnetUrl == null) return null;

            final hash = _extractInfoHash(magnetUrl);
            return {
              'title': c.title, // Use the REAL title we found
              'infoHash': hash,
              'magnetUrl': magnetUrl,
              'provider': '1337x',
              'seeders':
                  0, // 1337x scraping often misses seeds unless we parse list
            };
          } catch (_) {
            return null;
          }
        }),
      );

      return results.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  // Helper struct for candidates
  List<({String url, String title})> _extractCandidates(String html) {
    final candidates = <({String url, String title})>[];
    // Regex matches: href="/torrent/12345/Title-Here/"
    final regex = RegExp(r'href="(/torrent/\d+/([^/"]+)/)"');

    for (final match in regex.allMatches(html)) {
      final url = match.group(1);
      final slug = match.group(2);

      if (url != null && slug != null) {
        // De-slugify: "The-Matrix-1999" -> "The Matrix 1999"
        final title = slug.replaceAll('-', ' ');
        candidates.add((url: url, title: title));
      }
    }
    return candidates;
  }

  String? _extractMagnet(String html) {
    final regex = RegExp(
      r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
      caseSensitive: false,
    );
    return regex.firstMatch(html)?.group(1);
  }

  // ... (keep cinemeta helpers) ...
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

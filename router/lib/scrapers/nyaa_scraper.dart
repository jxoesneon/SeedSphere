import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/scraper_engine.dart';

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
      // 1. Fetch metadata title from Cinemeta (same as legacy)
      // Nyaa needs a query string, not just an ID
      // We can infer type from ID format roughly, but Cinemeta is safer or just try both
      // For simplicity, assume if it's series/movie we need title.
      // But BaseScraper only gives us ID.
      // Let's port the _fetchCinemetaTitle logic

      // Actually standard IMDB IDs don't distinguish type easily without lookup.
      // We'll try fetching metadata for 'series' then 'movie' or rely on what we find.
      // Porting the logic from NyaaProvider:

      final metaInfo =
          await _fetchCinemetaTitle('series', imdbId) ??
          await _fetchCinemetaTitle('movie', imdbId);

      if (metaInfo == null) return [];

      final searchQuery = Uri.encodeComponent(metaInfo['title'] as String);
      final url = '$baseUrl/?f=0&c=0_0&q=$searchQuery';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return [];

      final magnets = _parseMagnetsFromHtml(response.body);

      return magnets.take(40).map((magnetUrl) {
        final hash = _extractInfoHash(magnetUrl);
        return {
          'title': metaInfo['title'] ?? 'Nyaa',
          'infoHash': hash,
          'magnetUrl': magnetUrl,
          'provider': 'Nyaa',
        };
      }).toList();
    } catch (_) {
      return [];
    }
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

  String? _extractInfoHash(String magnetUrl) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetUrl);
    return match?.group(1)?.toLowerCase();
  }
}

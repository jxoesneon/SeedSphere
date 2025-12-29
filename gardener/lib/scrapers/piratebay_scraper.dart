import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';

/// Scraper implementation for the Pirate Bay provider (Classic).
class PirateBayScraper extends BaseScraper {
  final http.Client _client;

  PirateBayScraper({http.Client? client})
      : _client = client ?? http.Client(),
        super(name: 'Pirate Bay', baseUrl: 'https://thepiratebay.org');

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    try {
      final type = imdbId.contains('tt') ? 'series' : 'movie';

      var metaInfo = await _fetchCinemetaTitle(type, imdbId);
      if (metaInfo == null && type == 'series') {
        metaInfo = await _fetchCinemetaTitle('movie', imdbId);
      }

      if (metaInfo == null) return [];

      final searchQuery = Uri.encodeComponent(metaInfo['title'] as String);
      // Order by seeds (99), page 1, category 0 (all)
      final url = '$baseUrl/search/$searchQuery/1/99/0';

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) return [];

      // ReDoS Protection: Limit analysis to first 2MB
      String html = response.body;
      if (html.length > 2 * 1024 * 1024) {
        html = html.substring(0, 2 * 1024 * 1024);
      }

      final magnets = _parseMagnetsFromHtml(html);

      return magnets.take(40).map((magnetUrl) {
        final hash = _extractInfoHash(magnetUrl);
        return {
          'title': metaInfo!['title'] ?? 'PirateBay',
          'infoHash': hash,
          'magnetUrl': magnetUrl,
          'provider': 'PirateBay'
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _parseMagnetsFromHtml(String html) {
    final magnets = <String>{};
    final regex = RegExp(r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
        caseSensitive: false);

    for (final match in regex.allMatches(html)) {
      final magnetUrl = match.group(1);
      if (magnetUrl != null && magnetUrl.startsWith('magnet:?')) {
        magnets.add(magnetUrl);
      }
    }

    return magnets.toList();
  }

  Future<Map<String, dynamic>?> _fetchCinemetaTitle(
      String type, String id) async {
    try {
      final url = 'https://v3-cinemeta.strem.io/meta/$type/$id.json';
      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 2),
          );

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

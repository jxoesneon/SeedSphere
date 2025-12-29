import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';

class TokyoToshoScraper extends BaseScraper {
  final http.Client _client;

  TokyoToshoScraper({http.Client? client})
      : _client = client ?? http.Client(),
        super(name: 'TokyoTosho', baseUrl: 'https://tokyotosho.info');

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    try {
      final metaInfo = await _fetchCinemetaTitle('series', imdbId) ??
          await _fetchCinemetaTitle('movie', imdbId);
      if (metaInfo == null) return [];

      final q = Uri.encodeComponent(metaInfo['title'] as String);
      final url =
          '$baseUrl/search.php?terms=$q&type=0&size_min=&size_max=&username=';

      final response =
          await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      return _parseMagnetsFromHtml(response.body)
          .take(30)
          .map((m) => {
                'title': metaInfo['title'],
                'infoHash': _extractInfoHash(m),
                'magnetUrl': m,
                'provider': 'TokyoTosho'
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchCinemetaTitle(
      String type, String id) async {
    try {
      final url = 'https://v3-cinemeta.strem.io/meta/$type/$id.json';
      final response =
          await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return data['meta'] != null ? {'title': data['meta']['name']} : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _parseMagnetsFromHtml(String html) {
    final magnets = <String>{};
    final regex = RegExp(r"""href=["\']?(magnet:\?xt=[^"\s\']+)["\']?""",
        caseSensitive: false);
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

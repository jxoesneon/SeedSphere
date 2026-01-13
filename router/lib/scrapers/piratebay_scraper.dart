import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/scraper_engine.dart';
import 'package:router/core/title_verifier.dart';

/// Scraper implementation for the Pirate Bay provider (Classic).
class PirateBayScraper extends BaseScraper {
  final http.Client _client;

  /// Creates a new PirateBayScraper.
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
      final requestedTitle = metaInfo['title'] as String;
      final requestedYear = int.tryParse(metaInfo['year'].toString());

      final searchQuery = Uri.encodeComponent(requestedTitle);
      // Order by seeds (99), page 1, category 0 (all)
      final url = '$baseUrl/search/$searchQuery/1/99/0';

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      // ReDoS Protection: Limit analysis to first 2MB
      String html = response.body;
      if (html.length > 2 * 1024 * 1024) {
        html = html.substring(0, 2 * 1024 * 1024);
      }

      final results = _parseResults(html);

      // Verify and Map
      final validStreams = <Map<String, dynamic>>[];

      for (var result in results) {
        if (TitleVerifier.verify(
          requestedTitle,
          result.title,
          year: requestedYear,
        )) {
          final hash = _extractInfoHash(result.magnet);
          validStreams.add({
            'title': result.title,
            'infoHash': hash,
            'magnetUrl': result.magnet,
            'provider': 'PirateBay',
            'seeders':
                0, // TPB scraping seeds is harder, explicit 0 implies unknown
          });
        }
      }

      return validStreams.take(40).toList();
    } catch (_) {
      return [];
    }
  }

  // Parse pairs of (Title, Magnet)
  List<({String title, String magnet})> _parseResults(String html) {
    final results = <({String title, String magnet})>[];

    // Split by table row to keep title/magnet paired
    // TPB uses <tr class="header"> for header, then normal <tr> for items
    final rows = html.split('<tr');

    for (var row in rows) {
      // Extract Title: class="detLink" title="Details for The Matrix"
      // OR >The Matrix<
      final titleMatch = RegExp(
        r'class="detLink" title="Details for ([^"]+)"',
      ).firstMatch(row);
      if (titleMatch == null) continue;

      final title = titleMatch.group(1)!;

      // Extract Magnet
      final magnetMatch = RegExp(
        r'href="(magnet:\?xt=urn:btih:[^"]+)"',
      ).firstMatch(row);
      if (magnetMatch == null) continue;

      results.add((title: title, magnet: magnetMatch.group(1)!));
    }

    return results;
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

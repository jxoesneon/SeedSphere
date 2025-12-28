import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/scraper_engine.dart';

/// Scraper implementation for the EZTV provider (TV Series).
class EztvScraper extends BaseScraper {
  final http.Client _client;

  EztvScraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: 'EZTV', baseUrl: 'https://eztv.re/api');

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    // EZTV is focused on TV Series; simple check if ID looks like TT ID but logic is mainly in API
    try {
      final url =
          '$baseUrl/get-torrents?imdb_id=${imdbId.replaceFirst("tt", "")}&limit=100';
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<Map<String, dynamic>> streams = [];

      final torrents = data['torrents'] as List?;
      if (torrents != null) {
        for (var t in torrents) {
          final magnet = t['magnet_url'] as String?;
          if (magnet != null && magnet.startsWith('magnet:?')) {
            streams.add({
              'title': t['title'] ?? 'EZTV',
              'infoHash': t['hash'],
              'magnetUrl': magnet,
              'seeds': t['seeds'],
              'peers': t['peers'],
              'size': t['size'],
              'sizeBytes': t['size_bytes'],
              'provider': 'EZTV',
            });
          }
        }
      }
      return streams;
    } catch (_) {
      return [];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/scraper_engine.dart';

/// Scraper implementation for the YTS.mx API.
///
/// Fetches movie torrent metadata using the YTS REST API. It identifies
/// movies by IMDB ID and extracts multiple quality versions (720p, 1080p, 2160p).
///
/// Example:
/// ```dart
/// final yts = YTSScraper();
/// final results = await yts.scrape('tt1375666'); // Inception
/// ```
class YTSScraper extends BaseScraper {
  final http.Client _client;

  /// Creates a new [YTSScraper] instance.
  ///
  /// [client] - Optional HTTP client for testing. Defaults to standard HTTP client.
  YTSScraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: 'YTS', baseUrl: 'https://yts.mx/api/v2');

  /// Fetches metadata for all available torrents for the given [imdbId].
  ///
  /// Calls the YTS `list_movies.json` endpoint with a query term for the IMDB ID.
  ///
  /// Returns a list of maps containing:
  /// - `title`: Formatted string including movie title, quality, and type.
  /// - `infoHash`: The hex hash for the torrent.
  /// - `seeders`: Number of seeds.
  /// - `size`: Human-readable file size.
  ///
  /// Returns an empty list if no movies are found or if the API request fails.
  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    final response = await _client.get(
      Uri.parse(
        '$baseUrl/list_movies.json',
      ).replace(queryParameters: {'query_term': imdbId}),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final List<Map<String, dynamic>> streams = [];

    // YTS returns movie details inside data['movies'] if found
    if (data['data']['movie_count'] > 0) {
      final movie = data['data']['movies'][0];
      for (var torrent in movie['torrents']) {
        streams.add({
          'title':
              '${movie['title']} [${torrent['quality']}] [${torrent['type']}]',
          'infoHash': torrent['hash'],
          'seeders': torrent['seeds'],
          'size': torrent['size'],
        });
      }
    }

    return streams;
  }
}

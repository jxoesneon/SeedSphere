import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/scrapers/scraper_engine.dart';

/// Scraper implementation for the Torrentio stream aggregator.
///
/// Fetches stream metadata using the Torrentio Stremio addon interface.
/// It provides access to a wide variety of public trackers and cached
/// debrid streams for a given IMDB ID.
///
/// Example:
/// ```dart
/// final torrentio = TorrentioScraper();
/// final results = await torrentio.scrape('tt1375666');
/// ```
class TorrentioScraper extends BaseScraper {
  final http.Client _client;

  /// Creates a new [TorrentioScraper] instance.
  ///
  /// [client] - Optional HTTP client for testing. Defaults to standard HTTP client.
  TorrentioScraper({http.Client? client})
      : _client = client ?? http.Client(),
        super(name: 'Torrentio', baseUrl: 'https://torrentio.strem.fun');

  /// Fetches stream metadata for the specified [imdbId].
  ///
  /// Calls the Torrentio `stream/movie/{imdbId}.json` endpoint to retrieve
  /// a list of available streams.
  ///
  /// Returns a list of maps containing:
  /// - `title`: The stream title or name.
  /// - `infoHash`: The hex hash for the torrent.
  /// - `fileIdx`: Optional index of the specific file within the torrent.
  ///
  /// Returns an empty list if no streams are found or if the API request fails.
  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    final response =
        await _client.get(Uri.parse('$baseUrl/stream/movie/$imdbId.json'));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final List<Map<String, dynamic>> streams = [];

    // Torrentio returns a list of streams in the 'streams' field
    if (data['streams'] != null) {
      for (var stream in data['streams']) {
        streams.add({
          'title': stream['title'] ?? stream['name'],
          'infoHash': stream['infoHash'],
          'fileIdx': stream['fileIdx'],
        });
      }
    }

    return streams;
  }
}

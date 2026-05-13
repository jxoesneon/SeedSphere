import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:gardener/scrapers/scraper_engine.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:gardener/core/debug_logger.dart';

class TorznabScraper extends BaseScraper {
  final http.Client _client;
  final ConfigManager _config;

  TorznabScraper({http.Client? client, ConfigManager? config})
    : _client = client ?? http.Client(),
      _config = config ?? ConfigManager(),
      super(name: 'Torznab', baseUrl: ''); // baseUrl is dynamic from config

  @override
  Future<List<Map<String, dynamic>>> scrape(String imdbId) async {
    final baseUrl = _config.torznabUrl;
    final apiKey = await _config.getTorznabKey();

    if (baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return [];
    }

    // Determine type (tt... for movie/series)
    // Most indexers support t=movie with imdbid
    final url = '$baseUrl?t=movie&imdbid=$imdbId&apikey=$apiKey';

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        DebugLogger.warn('Torznab: Failed with status ${response.statusCode}');
        return [];
      }

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      final List<Map<String, dynamic>> results = [];

      for (var item in items) {
        final title = item.findElements('title').firstOrNull?.innerText ?? '';
        final link = item.findElements('link').firstOrNull?.innerText ?? '';

        // Extract torznab attributes
        int seeders = 0;
        int size = 0;
        String? infoHash;

        final attrs = item.findElements('torznab:attr');
        for (var attr in attrs) {
          final name = attr.getAttribute('name');
          final value = attr.getAttribute('value');
          if (name == 'seeders') seeders = int.tryParse(value ?? '0') ?? 0;
          if (name == 'size') size = int.tryParse(value ?? '0') ?? 0;
          if (name == 'infohash') infoHash = value;
        }

        // If no infohash, try to extract from magnet link
        if (infoHash == null && link.startsWith('magnet:')) {
          final hashMatch = RegExp(r'btih:([a-zA-Z0-9]+)').firstMatch(link);
          if (hashMatch != null) {
            infoHash = hashMatch.group(1);
          }
        }

        if (infoHash != null) {
          results.add({
            'title': title,
            'magnet': link.startsWith('magnet:')
                ? link
                : 'magnet:?xt=urn:btih:$infoHash',
            'infoHash': infoHash.toLowerCase(),
            'seeders': seeders,
            'size': size,
          });
        }
      }

      return results;
    } catch (e) {
      DebugLogger.error('Torznab: Error scraping', error: e);
      return [];
    }
  }

  @override
  bool isEnabled(ConfigManager config) => config.enableTorznab;
}

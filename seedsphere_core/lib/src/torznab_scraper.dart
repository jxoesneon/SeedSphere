import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'scraper_engine.dart';
import 'core/app_config.dart';

/// Scraper for Torznab-compatible indexers (Jackett, Prowlarr).
class TorznabScraper extends BaseScraper {
  final http.Client _client;
  final AppConfig _config;

  /// Creates a new TorznabScraper.
  TorznabScraper({http.Client? client, required AppConfig config})
    : _client = client ?? http.Client(),
      _config = config,
      super(name: 'Torznab', baseUrl: '');

  @override
  Future<List<Map<String, dynamic>>> scrape(
    String imdbId, {
    Function(String)? onLog,
  }) async {
    final baseUrl = _config.torznabUrl;
    final apiKey = await _config.getTorznabKey();

    if (baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return [];
    }

    final url = '$baseUrl?t=movie&imdbid=$imdbId&apikey=$apiKey';

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return [];
      }

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      final List<Map<String, dynamic>> results = [];

      for (var item in items) {
        final title = item.findElements('title').firstOrNull?.innerText ?? '';
        final link = item.findElements('link').firstOrNull?.innerText ?? '';

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
    } catch (_) {
      return [];
    }
  }
}

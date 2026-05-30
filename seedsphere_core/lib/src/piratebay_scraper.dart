import 'dart:convert';
import 'package:http/http.dart' as http;
import 'scraper_engine.dart';
import 'core/title_verifier.dart';

/// Scraper implementation for The Pirate Bay.
class PirateBayScraper extends BaseScraper {
  final http.Client _client;

  /// Creates a new PirateBayScraper.
  PirateBayScraper({http.Client? client})
    : _client = client ?? http.Client(),
      super(name: 'ThePirateBay', baseUrl: 'https://thepiratebay.org');

  @override
  Future<List<Map<String, dynamic>>> scrape(
    String imdbId, {
    String? title,
    int? year,
    Function(String)? onLog,
  }) async {
    try {
      String requestedTitle = title ?? '';
      int? requestedYear = year;
      final type = imdbId.startsWith('tt') ? 'movie' : 'series';

      if (requestedTitle.isEmpty) {
        final cinemeta = await _fetchCinemetaTitle(type, imdbId);
        if (cinemeta == null) return [];
        requestedTitle = cinemeta['title'] as String;
        requestedYear ??= int.tryParse(cinemeta['year'].toString());
      }

      final query = Uri.encodeComponent(requestedTitle);
      final searchUrl = '$baseUrl/search.php?q=$query&all=on&search=Pirate+Search';

      final response = await _client.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

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
          isSeries: type == 'series',
          onLog: onLog,
        )) {
          final hash = _extractInfoHash(result.magnet);

          // Verify Magnet DN as a secondary check
          final magnetDn = _extractMagnetDN(result.magnet);
          if (magnetDn != null) {
            final dnClean = Uri.decodeComponent(magnetDn).replaceAll('+', ' ');
            if (!TitleVerifier.verify(
              requestedTitle,
              dnClean,
              year: requestedYear,
              isSeries: type == 'series',
            )) {
              continue;
            }
          }

          validStreams.add({
            'title': result.title,
            'infoHash': hash,
            'magnet': result.magnet,
            'provider': 'PirateBay',
            'seeders': result.seeders,
          });
        }
      }

      return validStreams.take(40).toList();
    } catch (_) {
      return [];
    }
  }

  // Parse tuples of (Title, Magnet, Seeders)
  List<({String title, String magnet, int seeders})> _parseResults(String html) {
    final results = <({String title, String magnet, int seeders})>[];

    // Split by table row to keep data paired
    final rows = html.split('<tr');

    for (var row in rows) {
      // 1. Extract Title
      final titleMatch = RegExp(
        r'class="detLink" title="Details for ([^"]+)"',
      ).firstMatch(row);
      if (titleMatch == null) continue;
      final title = titleMatch.group(1)!;

      // 2. Extract Magnet
      final magnetMatch = RegExp(
        r'href="(magnet:\?xt=urn:btih:[^"]+)"',
      ).firstMatch(row);
      if (magnetMatch == null) continue;
      final magnet = magnetMatch.group(1)!;

      // 3. Extract Seeders (3rd or 4th cell usually)
      // TPB structure: <td>Type</td> <td>Title...</td> <td>Seeders</td> <td>Leechers</td>
      // We look for digits between <td> and </td> after the title link.
      int seeders = 0;
      final seederMatch = RegExp(r'<td align="right">(\d+)</td>').firstMatch(row);
      if (seederMatch != null) {
        seeders = int.tryParse(seederMatch.group(1)!) ?? 0;
      }

      results.add((title: title, magnet: magnet, seeders: seeders));
    }

    return results;
  }

  String? _extractInfoHash(String magnetUrl) {
    final match = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetUrl);
    return match?.group(1)?.toLowerCase();
  }

  String? _extractMagnetDN(String magnetUrl) {
    final match = RegExp(r'dn=([^&]+)').firstMatch(magnetUrl);
    return match?.group(1);
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
}

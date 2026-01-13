import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:router/scrapers/x1337_scraper.dart';
import 'package:router/scrapers/piratebay_scraper.dart';

/// Script to verify resolution success rate for Top 100 Movies and Series.
/// Run with: dart tool/verify_resolution.dart
void main() async {
  print('=== SeedSphere Resolution Verifier ===');
  print('Target: Top 100 Movies & Series');

  final client = http.Client();
  final x1337 = X1337Scraper(client: client);
  final tpb = PirateBayScraper(client: client);

  // 1. Fetch Lists
  print('\n[1/3] Fetching Catalogs from Cinemeta...');
  final movies = await _fetchCatalog(client, 'movie');
  final series = await _fetchCatalog(client, 'series');

  print('Loaded ${movies.length} Movies and ${series.length} Series.');

  // 2. Verify Movies
  print('\n[2/3] Verifying Movies...');
  final movieStats = await _verifyItems(movies, [x1337, tpb], 'Movie');

  // 3. Verify Series
  print('\n[3/3] Verifying Series...');
  final seriesStats = await _verifyItems(series, [x1337, tpb], 'Series');

  // 4. Report
  print('\n=== FINAL REPORT ===');
  _printStats('Movies', movieStats);
  _printStats('Series', seriesStats);

  client.close();
  exit(0);
}

Future<List<Map<String, dynamic>>> _fetchCatalog(
  http.Client client,
  String type,
) async {
  try {
    // Standard Stremio/Cinemeta catalog endpoint
    final url = 'https://v3-cinemeta.strem.io/catalog/$type/top.json';
    final response = await client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      print('Failed to fetch $type catalog: ${response.statusCode}');
      return [];
    }

    final data = jsonDecode(response.body);
    final metas = (data['metas'] as List).cast<Map<String, dynamic>>();
    return metas.take(100).toList();
  } catch (e) {
    print('Error fetching $type catalog: $e');
    return [];
  }
}

Future<ResolutionStats> _verifyItems(
  List<Map<String, dynamic>> items,
  List<dynamic> scrapers,
  String label,
) async {
  int success = 0;
  int failed = 0;
  final failures = <String>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final title = item['name'];
    final id =
        item['imdb_id'] ?? item['id']; // Stremio usually sends 'id' as imdb_id

    stdout.write(
      'Checking ($label ${i + 1}/${items.length}) "$title" [$id]... ',
    );

    bool found = false;
    int streamCount = 0;

    // Try all scrapers
    for (var scraper in scrapers) {
      if (found)
        break; // Optimization: stop if already found (unless we want to test all)
      try {
        final results = await scraper.scrape(id);
        if (results.isNotEmpty) {
          found = true;
          streamCount = results.length;
        }
      } catch (e) {
        // ignore individual scrape errors
      }
    }

    if (found) {
      print('✅ OK ($streamCount streams)');
      success++;
    } else {
      print('❌ FAILED');
      failures.add('$title [$id]');
      failed++;
    }

    // Rate limiting kindness
    await Future.delayed(const Duration(milliseconds: 200));
  }

  return ResolutionStats(success, failed, failures);
}

void _printStats(String category, ResolutionStats stats) {
  final total = stats.success + stats.failed;
  final percentage = total == 0
      ? 0
      : (stats.success / total * 100).toStringAsFixed(1);

  print('\n--- $category Results ---');
  print('Total: $total');
  print('Success: ${stats.success} ($percentage%)');
  print('Failed: ${stats.failed}');

  if (stats.failures.isNotEmpty) {
    print('Failures:');
    for (var f in stats.failures.take(10)) {
      print(' - $f');
    }
    if (stats.failures.length > 10) {
      print(' ... and ${stats.failures.length - 10} more.');
    }
  }
}

class ResolutionStats {
  final int success;
  final int failed;
  final List<String> failures;

  ResolutionStats(this.success, this.failed, this.failures);
}

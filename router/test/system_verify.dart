import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// System Integration Verification Script (Real World Content)
///
/// Verifies Metadata & Stream Resolution for:
/// 1. Movie: Dune: Part Two (tt15239678)
/// 2. Series: Fallout S01E01 (tt12637874)
void main() async {
  print('--- SeedSphere System Verification (Real World Content) ---');

  final bridgeUrl = 'http://localhost:8787';

  // Helper function to query and print results
  Future<void> testContent(String type, String id, String name) async {
    print('\nTesting $type resolution for "$name" ($id)...');
    try {
      final url = '$bridgeUrl/stream/$type/$id.json';
      print('GET $url');

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final streams = json['streams'] as List;
        print('✅ Success: Found ${streams.length} streams');

        if (streams.isNotEmpty) {
          // Print top 3 streams
          print('Top 3 Streams:');
          for (var i = 0; i < (streams.length < 3 ? streams.length : 3); i++) {
            final s = streams[i];
            print(
              '  ${i + 1}. [${s['name']}] ${s['title'].replaceAll('\n', ' ')}',
            );
            if (s['seeds'] != null)
              print('     🌱 Seeds: ${s['seeds']}  👥 Peers: ${s['peers']}');
          }
        } else {
          print(
            '⚠️ No streams found. This might be due to scraper blocks or no cached results.',
          );
        }
      } else {
        print('❌ Failed: HTTP ${res.statusCode}');
        print('Body: ${res.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // 1. Recent Movie: Dune: Part Two
  await testContent('movie', 'tt15239678', 'Dune: Part Two');

  // 2. Recent Series: Fallout (S01E01)
  // Stremio format for episodes: tt12637874:1:1
  await testContent('series', 'tt12637874:1:1', 'Fallout S01E01');

  // 3. Recent Series: The Boys (S04E01)
  // tt1190634:4:1
  await testContent('series', 'tt1190634:4:1', 'The Boys S04E01');

  print('\n--- Verification Complete ---');
}

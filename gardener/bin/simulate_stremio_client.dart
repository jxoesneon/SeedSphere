// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// USAGE:
/// 1. Run Gardener: flutter run
/// 2. Run this script: dart bin/simulate_stremio_client.dart
///
/// This script mimics the Stremio Client behavior, querying the local addon
/// for its manifest and resolving a specific stream (The Matrix).

const List<int> ports = [7001, 7000];
const String testImdbId = 'tt0133093'; // The Matrix (1999)

Future<void> main() async {
  print('🎬 Stremio Client Simulator v1.0');
  print('=================================');

  // 1. Find Running Server
  String? baseUrl;
  for (final port in ports) {
    try {
      final url = 'http://127.0.0.1:$port/manifest.json';
      print('🔍 Probing $url...');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode == 200) {
        baseUrl = 'http://127.0.0.1:$port';
        print('✅ Found Gardener Addon at $baseUrl');
        break;
      }
    } catch (_) {
      // Ignore connection errors
    }
  }

  if (baseUrl == null) {
    print('❌ Could not find running Gardener instance.');
    print(
      '   Please ensure the app is running (flutter run -d macos/windows/linux).',
    );
    print('   Checked ports: $ports');
    exit(1);
  }

  // 2. Validate Manifest
  try {
    print('\n📜 Fetching Manifest...');
    final manifestUrl = Uri.parse('$baseUrl/manifest.json');
    final response = await http.get(manifestUrl);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print('   Name: ${json['name']}');
      print('   Version: ${json['version']}');
      print('   Description: ${json['description']}');
      print('   Resources: ${json['resources']}');
      print('✅ Manifest Validated');
    } else {
      print('❌ Manifest Error: ${response.statusCode}');
      exit(1);
    }
  } catch (e) {
    print('❌ Manifest Request Failed: $e');
    exit(1);
  }

  // 3. Resolve Stream
  try {
    print('\n🍿 Resolving Stream: The Matrix ($testImdbId)...');
    print('   (This may take a few seconds as providers are scraped)');

    final stopwatch = Stopwatch()..start();
    final streamUrl = Uri.parse('$baseUrl/stream/movie/$testImdbId.json');
    final response = await http.get(streamUrl);
    stopwatch.stop();

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final streams = json['streams'] as List;

      print(
        '✅ Resolution Complete in ${stopwatch.elapsed.inSeconds}.${stopwatch.elapsedMilliseconds % 1000}s',
      );
      print('   Found ${streams.length} streams.');

      if (streams.isNotEmpty) {
        print('\n🏆 Top Result:');
        final top = streams.first;
        final titleLines = top['title'].toString().split('\n');

        print('   Title: ${titleLines.first}');
        if (titleLines.length > 1) {
          print('   Details: ${titleLines.skip(1).join('\n            ')}');
        }
        print('   URL: ${top['url']}');
        print('   InfoHash: ${top['infoHash']}');

        if (streams.length > 1) {
          print('\n   Other results count: ${streams.length - 1}');
        }
      } else {
        print(
          '⚠️ No streams found. Check Provider Settings or internet connection.',
        );
      }
    } else {
      print('❌ Stream Request Failed: ${response.statusCode}');
      print('   Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Stream Resolution Error: $e');
  }
}

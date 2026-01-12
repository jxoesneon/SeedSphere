import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/providers/debrid_provider.dart';

/// Implementation of [DebridProvider] for Real-Debrid.
class RealDebridProvider implements DebridProvider {
  final String _apiKey;
  final http.Client _client;
  static const _baseUrl = NetworkConstants.debridApiBase;

  RealDebridProvider(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'real_debrid';

  @override
  Future<Map<String, dynamic>> getUser() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/user'),
      headers: {'Authorization': 'Bearer $_apiKey'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('RealDebrid: Failed to get user: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> addMagnet(
    String magnet, {
    Map<String, dynamic>? options,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/torrents/addMagnet'),
      headers: {'Authorization': 'Bearer $_apiKey'},
      body: {'magnet': magnet},
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'RealDebrid: Failed to add magnet: ${response.statusCode}',
      );
    }
  }

  @override
  Future<void> selectFiles(String id, String fileIds) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/torrents/selectFiles/$id'),
      headers: {'Authorization': 'Bearer $_apiKey'},
      body: {'files': fileIds},
    );

    if (response.statusCode != 204 && response.statusCode != 202) {
      // 202 is sometimes returned during processing? 204 is success.
      // Treat anything else as error.
      throw Exception(
        'RealDebrid: Failed to select files: ${response.statusCode}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getTorrentInfo(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/torrents/info/$id'),
      headers: {'Authorization': 'Bearer $_apiKey'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'RealDebrid: Failed to get torrent info: ${response.statusCode}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> unrestrictLink(String link) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/unrestrict/link'),
      headers: {'Authorization': 'Bearer $_apiKey'},
      body: {'link': link},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'RealDebrid: Failed to unrestrict link: ${response.body}',
      );
    }
  }

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty) return {};

    final result = <String, bool>{};
    const chunkSize = 50;

    for (var i = 0; i < hashes.length; i += chunkSize) {
      final chunk = hashes.sublist(
        i,
        (i + chunkSize) > hashes.length ? hashes.length : (i + chunkSize),
      );

      final hashStr = chunk.join('/');
      try {
        final response = await _client.get(
          Uri.parse('$_baseUrl/torrents/instantAvailability/$hashStr'),
          headers: {'Authorization': 'Bearer $_apiKey'},
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          for (final hash in chunk) {
            final lowerHash = hash.toLowerCase();
            final data = json[lowerHash];
            if (data != null &&
                data['rd'] is List &&
                (data['rd'] as List).isNotEmpty) {
              result[hash] = true;
            } else {
              result[hash] = false;
            }
          }
        }
      } catch (e) {
        DebugLogger.warn(
          'RealDebridProvider: Chunk availability check failed: $e',
        );
        // Fallback for this chunk: all false
        for (final hash in chunk) {
          result[hash] = false;
        }
      }
    }
    return result;
  }
}

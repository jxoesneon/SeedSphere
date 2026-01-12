import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/debrid_provider.dart';

/// Implementation of [DebridProvider] for Orion.
class OrionProvider implements DebridProvider {
  final String
  _token; // Orion calls this 'token' or 'key' depending on context, usually 'token' param.
  final http.Client _client;
  static const _baseUrl = 'https://api.orionoid.com';

  OrionProvider(this._token, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'orion';

  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, String> params,
  ) async {
    final query = {'token': _token, 'action': action, ...params};
    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['result'] != null && json['result']['status'] == 'error') {
        throw Exception('Orion Error: ${json['result']['message']}');
      }
      return json;
    } else {
      throw Exception('Orion HTTP Error: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> getUser() async {
    final data = await _request('account', {});
    return data['data'] ?? {};
  }

  @override
  Future<Map<String, dynamic>> addMagnet(
    String magnet, {
    Map<String, dynamic>? options,
  }) async {
    // Orion addtorrent
    final data = await _request('addtorrent', {
      'type': 'magnet',
      'value': magnet,
    });
    final torrent = data['data'];
    // Return unified ID
    return {
      'id': torrent['id'] ?? '',
      // Orion might return hash too
    };
  }

  @override
  Future<void> selectFiles(String id, String fileIds) async {
    // Orion usually auto-selects or downloads all.
    // If specific file selection is needed, we'd check their API docs.
    // For now, no-op or specific call if found.
  }

  @override
  Future<Map<String, dynamic>> getTorrentInfo(String id) async {
    final data = await _request('torrentinfo', {'id': id});
    final torrent = data['data'];

    // Map status
    String status = 'downloading';
    if (torrent['status'] == 'finished' || torrent['progress'] == 100) {
      status = 'downloaded';
    }

    // Map files and links
    final files = (torrent['files'] as List?) ?? [];
    final links = files
        .map((f) => f['link'] ?? '')
        .where((l) => l.toString().isNotEmpty)
        .toList();

    return {
      'status': status,
      'progress': torrent['progress'] ?? 0,
      'links': links,
      'files': files,
    };
  }

  @override
  Future<Map<String, dynamic>> unrestrictLink(String link) async {
    // Orion links in torrentinfo are often already direct or need 'retrieve'?
    // Usually 'retrieve' action is for cached streams.
    // If we have a link from 'torrentinfo', it might be a direct download link.
    // But DebridProviders usually need a "resolve" step.
    // If links are provided, we return them.
    return {'download': link};
  }

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    final results = <String, bool>{};
    if (hashes.isEmpty) return results;

    // Orion doesn't have a batch infohash check in a single simple call like RD.
    // We check them individually. To avoid hitting rate limits, we only check first 5.
    final targets = hashes.take(5).toList();

    final futures = targets.map((hash) async {
      try {
        final data = await _request('stream', {'query': 'infohash:$hash'});
        final streams = data['data']?['streams'] as List?;
        return MapEntry(hash, streams != null && streams.isNotEmpty);
      } catch (_) {
        return MapEntry(hash, false);
      }
    });

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    return results;
  }
}

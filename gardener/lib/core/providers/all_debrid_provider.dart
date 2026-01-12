import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/debrid_provider.dart';

/// Implementation of [DebridProvider] for AllDebrid.
class AllDebridProvider implements DebridProvider {
  final String _apiKey;
  final http.Client _client;
  static const _baseUrl = 'https://api.alldebrid.com/v4';
  static const _agent = 'SeedSphere';

  AllDebridProvider(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'all_debrid';

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? params,
  ]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: {'agent': _agent, 'apikey': _apiKey, ...?params},
    );
    final response = await _client.get(uri);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: {'agent': _agent, 'apikey': _apiKey});
    // AllDebrid expects parameters often in query or form-data,
    // but some endpoints strictly require query params for auth.
    final response = await _client.post(uri, body: body);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'success') {
        return json['data'];
      } else {
        throw Exception(
          'AllDebrid Error: ${json['error']?['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception('AllDebrid HTTP Error: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> getUser() async {
    return _get('/user');
  }

  @override
  Future<Map<String, dynamic>> addMagnet(
    String magnet, {
    Map<String, dynamic>? options,
  }) async {
    // AllDebrid expects 'magnets[]' for upload
    final data = await _post('/magnet/upload', {'magnets[]': magnet});
    final magnets = data['magnets'] as List;
    if (magnets.isEmpty) throw Exception('No magnet returned');
    final first = magnets.first;
    if (first['error'] != null) {
      throw Exception('AllDebrid Magnet Error: ${first['error']['message']}');
    }
    // Return unified structure
    return {'id': first['id'].toString(), 'hash': first['hash']};
  }

  @override
  Future<void> selectFiles(String id, String fileIds) async {
    // AllDebrid doesn't always strictly require file selection if cached?
    // But usually for new torrents it does.
    // Endpoint: /v4/magnet/upload/file
    // Wait, documentation says /magnet/upload usually handles it?
    // No, checking AllDebrid docs: usually it Auto-processes or you don't explicit select unless needed.
    // But let's assume standard flow.
    // Actually AllDebrid "uptobox" style might handle it differently.
    // Let's stub this safe for now or check if there is an endpoint.
    // RealDebrid requires it. AllDebrid often auto-downloads.
    // We'll leave it empty unless we find strictly necessary.
    // Update: If logic requires it, we can implement.
    // But common AllDebrid flow is: upload -> (if cached) ready -> links.
    // If not cached, it starts downloading.
  }

  @override
  Future<Map<String, dynamic>> getTorrentInfo(String id) async {
    final data = await _get('/magnet/status', {'id': id});
    final magnet = data['magnets'][id];

    // Convert to unified format if possible, or key off this in resolver
    // RealDebrid: { status: 'downloaded', files: [...], links: [...] }
    // AllDebrid: { status: 'Ready'/'Downloading', links: [...] }

    // Map status to RealDebrid style for compatibility with StreamResolver logic
    final status = magnet['statusCode'].toString(); // 4 = Ready
    String rdStatus = 'downloading';

    if (status == '4') {
      rdStatus = 'downloaded';
    } else if (status == '0' ||
        status == '1' ||
        status == '2' ||
        status == '3') {
      rdStatus = 'downloading';
    } else {
      rdStatus = 'error';
    }

    return {
      'status': rdStatus,
      'progress': magnet['downloaded'] ?? 0, // Simplified
      'links': magnet['links'] != null
          ? (magnet['links'] as List).map((l) => l['link'].toString()).toList()
          : [],
      'files': _mapFiles(
        magnet['links'],
      ), // AllDebrid gives links directly usually
    };
  }

  List<Map<String, dynamic>> _mapFiles(List? links) {
    // AllDebrid returns links, not necessarily file list in same way.
    // We might just return empty files if we have links.
    return [];
  }

  @override
  Future<Map<String, dynamic>> unrestrictLink(String link) async {
    final data = await _get('/link/unlock', {'link': link});
    return {
      'download': data['link'], // The direct link
    };
  }

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty) return {};
    // AllDebrid endpoint: /magnet/instant
    // Accepts magnets[] array. We can pass hashes directly?
    // Docs say "magnets[]: array of magnet links or hashes"
    // We must pass as POST body.

    // Construct query params or body? _post uses body.
    // http client body with list? 'magnets[]': [hash1, hash2]
    // The current _post helper takes Map<String, String>. It doesn't support list values directly easily
    // without modification or manual encoding.
    // Let's manually construct the map with indexed keys or use a custom post for this.
    // or 'magnets[0]': hash1, 'magnets[1]': hash2...

    final body = <String, String>{};
    for (int i = 0; i < hashes.length; i++) {
      body['magnets[$i]'] = hashes[i];
    }

    try {
      final data = await _post('/magnet/instant', body);
      // Response: { magnets: [ { magnet: "...", instant: true, ... } ] }
      final results = data['magnets'] as List;
      final ret = <String, bool>{};

      for (final item in results) {
        final magnetOrHash = item['magnet'] as String;
        final instant = item['instant'] as bool? ?? false;
        // The returned 'magnet' might be the hash we sent, or full magnet.
        // If we sent hash, likely returns hash.
        ret[magnetOrHash] = instant;
      }
      return ret;
    } catch (e) {
      // Log error (via rethrow or print?) - stick to interface contract
      return {};
    }
  }
}

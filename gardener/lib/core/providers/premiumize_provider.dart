import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/providers/debrid_provider.dart';

/// Implementation of [DebridProvider] for Premiumize.me.
class PremiumizeProvider implements DebridProvider {
  final String _apiKey;
  final http.Client _client;
  static const _baseUrl = 'https://www.premiumize.me/api';

  PremiumizeProvider(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'premiumize';

  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, String> params, {
    bool isPost = false,
  }) async {
    final query = {'apikey': _apiKey, ...params};

    // Premiumize usually uses POST for actions (transfer/create) and GET for reads.
    // For simplicity, we can mostly use POST or GET depending on endpoint docs.
    // 'transfer/create' is POST. 'transfer/list' is GET.

    final uri = Uri.parse(
      '$_baseUrl/$endpoint',
    ).replace(queryParameters: query);
    http.Response response;

    if (isPost) {
      response = await _client.post(uri);
    } else {
      response = await _client.get(uri);
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'error') {
        throw Exception('Premiumize Error: ${json['message']}');
      }
      return json;
    } else {
      throw Exception('Premiumize HTTP Error: ${response.statusCode}');
    }
  }

  @override
  Future<Map<String, dynamic>> getUser() async {
    final data = await _request('account/info', {});
    return data;
  }

  @override
  Future<Map<String, dynamic>> addMagnet(
    String magnet, {
    Map<String, dynamic>? options,
  }) async {
    // Premiumize transfer/create
    final data = await _request('transfer/create', {
      'src': magnet,
    }, isPost: true);
    // Returns {status: success, id: "transfer_id", name: "..."}
    return {'id': data['id'] ?? ''};
  }

  @override
  Future<void> selectFiles(String id, String fileIds) async {
    // Premiumize usually auto-downloads. No explicit file selection needed for "start".
    // However, if we want to "browse" the content, we do it in getTorrentInfo.
    // There isn't a "select files" endpoint like Real-Debrid.
  }

  @override
  Future<Map<String, dynamic>> getTorrentInfo(String id) async {
    // Premiumize transfer/list to check progress? Or specific transfer check?
    // /transfer/list is generic.
    // /transfer/list doesn't filter by ID easily in docs?
    // Actually, transfers are listed. We have to find our ID.
    // Assuming 'id' is transfer ID.

    // NOTE: Premiumize doesn't have a direct "get transfer info" endpoint easily accessible,
    // usually we fetch list and filter.
    final listData = await _request('transfer/list', {});
    final transfers = (listData['transfers'] as List?) ?? [];

    final transfer = transfers.firstWhere(
      (t) => t['id'] == id,
      orElse: () => null,
    );

    if (transfer == null) {
      // Maybe it finished and moved to folder?
      // For now assume assume error or deleted if not found shortly after add.
      return {'status': 'error', 'progress': 0, 'files': [], 'links': []};
    }

    String status = 'downloading';
    if (transfer['status'] == 'finished' || transfer['status'] == 'seeding') {
      status = 'downloaded';
    } else if (transfer['status'] == 'error' ||
        transfer['status'] == 'timeout') {
      status = 'error';
    }

    // If downloaded, we need the files/links.
    // Premiumize moves finished transfers to root folder or 'file_id' or 'folder_id'.
    // If 'folder_id' is present, we need to list that folder.
    List links = [];
    List files = [];

    if (status == 'downloaded' && transfer['folder_id'] != null) {
      final folderContent = await _request('folder/list', {
        'id': transfer['folder_id'],
      });
      final content = (folderContent['content'] as List?) ?? [];

      // Map to standardized structure
      files = content
          .map(
            (f) => {
              'id': f['id'],
              'path': f['name'],
              'bytes': f['size'],
              'link':
                  f['link'], // Premiumize provides direct link in folder listing
            },
          )
          .toList();

      links = files.map((f) => f['link']).where((l) => l != null).toList();
    }

    return {
      'status': status,
      'progress': (transfer['progress'] as num?)?.toDouble() ?? 0.0,
      'links': links,
      'files': files,
    };
  }

  @override
  Future<Map<String, dynamic>> unrestrictLink(String link) async {
    // Premiumize links from folder/list are already direct/unrestricted usually.
    // But if we have a magnet link or something else, we might use /transfer/directdl?
    // The link from folder listing is usually the streaming link.
    return {'download': link};
  }

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty) return {};
    // Premiumize endpoint: /cache/check
    // Params: items[] = hash
    // Premiumize endpoint: /cache/check
    // Params: items[] = hash
    // Using manual query construction for repeated keys if http doesn't support
    // But this _request helper uses replace(queryParameters: ...) which supports List<String> values?
    // Dart Uri.replace supports Map<String, dynamic> where dynamic can be Iterable<String>.
    // Let's try passing list.

    // Wait, _request takes Map<String, String>. I need to modify it or bypass it.
    // _request: Map<String, String> query.
    // I'll bypass _request to handle the array parameter correctly or use repeated keys.
    // Uri doesn't strictly support duplicate keys in Map for queryParameters unless using keys 'items[]'.
    // Actually Uri.queryParameters handles it if we pass 'items[]': val? No.
    // Uri.queryParameters value must be String or Iterable.
    // _request signature is Map<String, String>, so I can't pass List.
    // I need to use _client directly or modify _request.
    // I'll use _client directly for this one to be safe.

    final uri = Uri.parse('$_baseUrl/cache/check').replace(
      queryParameters: {
        'apikey': _apiKey,
        'items[]':
            hashes, // Uri handles Iterable by repeating key 'items[]' for each value
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          final responseList = json['response'] as List; // boolean list
          if (responseList.length != hashes.length) {
            // Mismatch?
            return {};
          }

          final ret = <String, bool>{};
          for (int i = 0; i < hashes.length; i++) {
            ret[hashes[i]] = responseList[i] as bool;
          }
          return ret;
        }
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}

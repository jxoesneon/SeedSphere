import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SwarmService {
  Future<Map<String, dynamic>?> scrapeSwarm(
    String infoHash,
    List<String> trackers, {
    int timeoutMs = 2500,
  }) async {
    final ihHex = _toHex(infoHash);
    if (ihHex == null) return null;

    for (const tracker in trackers) {
      if (!tracker.startsWith('http')) continue;
      try {
        final res = await _scrapeTracker(tracker, ihHex, timeoutMs);
        if (res != null) return res;
      } catch (_) {}
    }
    return null;
  }

  String? _toHex(String ih) {
    final s = ih.trim();
    if (RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(s)) return s.toLowerCase();
    // Simplified base32 to hex if needed, but usually we deal with hex or it's already handled.
    return null;
  }

  Future<Map<String, dynamic>?> _scrapeTracker(
    String announceUrl,
    String ihHex,
    int timeoutMs,
  ) async {
    final scrapeUrl = _toScrapeUrl(announceUrl);
    if (scrapeUrl == null) return null;

    final infoHashBytes = _hexToPctEncoded(ihHex);
    final finalUrl = Uri.parse('$scrapeUrl?info_hash=$infoHashBytes');

    try {
      final response = await http
          .get(finalUrl)
          .timeout(Duration(milliseconds: timeoutMs));
      if (response.statusCode != 200) return null;

      final decoded = _decodeBencode(response.bodyBytes);
      final files = decoded['files'];
      if (files == null) return null;

      // The key is a binary string of the 20-byte infohash
      final targetKey = _hexToBinary(ihHex);
      dynamic rec;
      files.forEach((k, v) {
        if (k == targetKey) rec = v;
      });

      if (rec == null) return null;

      return {
        'ok': true,
        'seeds': rec['complete'] ?? rec['seeders'] ?? 0,
        'leechers': rec['incomplete'] ?? rec['leechers'] ?? 0,
      };
    } catch (_) {
      return null;
    }
  }

  String? _toScrapeUrl(String announce) {
    try {
      final uri = Uri.parse(announce);
      final path = uri.path;
      String newPath;
      if (path.contains('/announce')) {
        newPath = path.replaceFirst('/announce', '/scrape');
      } else {
        newPath = path.endsWith('/') ? '${path}scrape' : '$path/scrape';
      }
      return uri.replace(path: newPath).toString();
    } catch (_) {
      return null;
    }
  }

  String _hexToPctEncoded(String hex) {
    final buffer = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      buffer.write('%${hex.substring(i, i + 2).toUpperCase()}');
    }
    return buffer.toString();
  }

  String _hexToBinary(String hex) {
    final List<int> bytes = [];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return String.fromCharCodes(bytes);
  }

  // --- MINIMAL BENCODE DECODER ---
  dynamic _decodeBencode(Uint8List data) {
    int i = 0;

    dynamic parse() {
      final char = String.fromCharCode(data[i]);
      if (char == 'i') {
        i++;
        final end = data.indexOf(101, i); // 'e'
        final val = int.parse(utf8.decode(data.sublistView(i, end)));
        i = end + 1;
        return val;
      }
      if (char == 'l') {
        i++;
        final list = [];
        while (String.fromCharCode(data[i]) != 'e') {
          list.add(parse());
        }
        i++;
        return list;
      }
      if (char == 'd') {
        i++;
        final dict = <String, dynamic>{};
        while (String.fromCharCode(data[i]) != 'e') {
          final key = parse() as String;
          final val = parse();
          dict[key] = val;
        }
        i++;
        return dict;
      }
      if (char.contains(RegExp(r'[0-9]'))) {
        final colon = data.indexOf(58, i); // ':'
        final len = int.parse(utf8.decode(data.sublistView(i, colon)));
        i = colon + 1;
        final val = data.sublistView(i, i + len);
        i += len;
        // Check if it's likely a string or binary
        try {
          return utf8.decode(val);
        } catch (_) {
          return String.fromCharCodes(val);
        }
      }
      throw Exception('Invalid bencode at $i');
    }

    return parse();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for interacting with the BitTorrent swarm via HTTP trackers.
class SwarmService {
  final http.Client _client;
  final Future<List<InternetAddress>> Function(String host) _dnsResolver;

  /// Creates a new SwarmService.
  SwarmService({
    http.Client? client,
    Future<List<InternetAddress>> Function(String host)? dnsResolver,
  }) : _client = client ?? http.Client(),
       _dnsResolver = dnsResolver ?? InternetAddress.lookup;

  /// Scrapes the specified [trackers] for a given [infoHash] to find peer counts.
  ///
  /// Returns a map with 'seeds' and 'leechers' on the first successful scrape,
  /// or null if all trackers fail/timeout.
  Future<Map<String, dynamic>?> scrapeSwarm(
    String infoHash,
    List<String> trackers, {
    int timeoutMs = 2500,
  }) async {
    final ihHex = _toHex(infoHash);
    if (ihHex == null) return null;

    for (final tracker in trackers) {
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
    // Generate Scrape URL
    final scrapeUrl = _toScrapeUrl(announceUrl);
    if (scrapeUrl == null) return null;

    // Encode info_hash
    final infoHashBytes = _hexToPctEncoded(ihHex);

    // SSRF/DNS Rebinding Check: Resolve and Pin IP
    final safeIp = await _resolveSafeIp(scrapeUrl);
    if (safeIp == null) return null;

    try {
      final originalUri = Uri.parse('$scrapeUrl?info_hash=$infoHashBytes');

      // Pin the IP address to prevent DNS rebinding
      // Check if IPv6 needs brackets
      var ipHost = safeIp.address;
      if (safeIp.type == InternetAddressType.IPv6 && !ipHost.startsWith('[')) {
        ipHost = '[$ipHost]';
      }

      final pinnedUri = originalUri.replace(host: ipHost);

      // FIX(ZeroDay): Disable redirects to prevent bypassing SSRF checks via 30x responses
      final request = http.Request('GET', pinnedUri);
      request.followRedirects = false;
      request.headers['Host'] = originalUri.host;

      final streamedRef = await _client
          .send(request)
          .timeout(Duration(milliseconds: timeoutMs));
      final response = await http.Response.fromStream(streamedRef);

      if (response.statusCode != 200) return null;

      final decoded = _decodeBencode(response.bodyBytes);
      if (decoded is! Map) return null;

      final files = decoded['files'];
      if (files is! Map) return null;

      final targetKey = _hexToBinary(ihHex);
      final rec = files[targetKey];

      if (rec is! Map) return null;

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

  // SSRF Protection: Validate tracker is public internet facing
  // Returns the resolved InternetAddress if safe, null otherwise.
  Future<InternetAddress?> _resolveSafeIp(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return null;

      // Skip localhost strings immediately
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return null;
      }

      // Resolve DNS
      final ips = await _dnsResolver(host);
      for (final ip in ips) {
        bool isSafe = true;

        // FIX(ZeroDay): Check for IPv4-mapped IPv6 addresses (e.g. ::ffff:192.168.1.1)
        if (ip.type == InternetAddressType.IPv6) {
          final raw = ip.rawAddress;
          // IPv4-mapped IPv6 addresses are 16 bytes long, starting with 10 bytes of 0x00 and 2 bytes of 0xFF
          if (raw.length == 16 && raw[10] == 0xff && raw[11] == 0xff) {
            final first = raw[12];
            final second = raw[13];
            // Check private IPv4 ranges on the mapped suffix
            if (first == 10) isSafe = false;
            if (first == 172 && (second >= 16 && second <= 31)) isSafe = false;
            if (first == 192 && second == 168) isSafe = false;
            if (first == 127) isSafe = false; // Loopback
          }
        }

        if (ip.type == InternetAddressType.IPv4) {
          if (ip.isLoopback || ip.isLinkLocal) isSafe = false;

          // Manual RFC1918 Check just in case .isPrivate isn't strict enough on some platforms
          final first = ip.rawAddress[0];
          final second = ip.rawAddress[1];
          if (first == 10) isSafe = false;
          if (first == 172 && (second >= 16 && second <= 31)) isSafe = false;
          if (first == 192 && second == 168) isSafe = false;
        } else if (ip.type == InternetAddressType.IPv6) {
          if (ip.isLoopback || ip.isLinkLocal) isSafe = false;
          // Unique local address fc00::/7
          if ((ip.rawAddress[0] & 0xFE) == 0xFC) isSafe = false;
        }

        if (isSafe) return ip; // Return first safe IP
      }
      return null;
    } catch (e) {
      // DNS failure or parse error -> Unsafe/Unusable
      return null;
    }
  }

  // --- MINIMAL BENCODE DECODER ---
  dynamic _decodeBencode(Uint8List data) {
    int i = 0;

    dynamic parse() {
      if (i >= data.length) throw Exception('Unexpected end of bencode');
      final char = String.fromCharCode(data[i]);
      if (char == 'i') {
        i++;
        final end = data.indexOf(101, i); // 'e'
        if (end == -1) throw Exception('Missing integer terminator');
        final val = int.parse(utf8.decode(data.sublist(i, end)));
        i = end + 1;
        return val;
      }
      if (char == 'l') {
        i++;
        final list = [];
        while (i < data.length && String.fromCharCode(data[i]) != 'e') {
          list.add(parse());
        }
        i++;
        return list;
      }
      if (char == 'd') {
        i++;
        final dict = <String, dynamic>{};
        while (i < data.length && String.fromCharCode(data[i]) != 'e') {
          final key = parse() as String;
          final val = parse();
          dict[key] = val;
        }
        i++;
        return dict;
      }
      if (RegExp(r'[0-9]').hasMatch(char)) {
        final colon = data.indexOf(58, i); // ':'
        if (colon == -1) throw Exception('Missing string colon');
        final len = int.parse(utf8.decode(data.sublist(i, colon)));
        i = colon + 1;
        if (i + len > data.length) throw Exception('String overflow');
        final val = data.sublist(i, i + len);
        i += len;

        // For Bencode, it's safer to treat strings as raw byte sequences
        // to avoid UTF-8 decoding errors with binary keys (like infohashes).
        return String.fromCharCodes(val);
      }
      throw Exception('Invalid bencode at $i: $char');
    }

    return parse();
  }
}

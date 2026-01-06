import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:http/http.dart' as http;

/// Centralized networking constants for SeedSphere.

/// Wrapped HTTP client for tracing requests/responses.
class HttpLogger {
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final startTime = DateTime.now();
    DebugLogger.info('-> POST $url', category: 'TRACE', error: _redact(body));

    try {
      final response = await http.post(url, headers: headers, body: body);
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      DebugLogger.info(
        '<- ${response.statusCode} (${duration}ms) $url',
        category: 'TRACE',
        error: _redact(response.body),
      );
      return response;
    } catch (e) {
      DebugLogger.error('<- FAIL $url', category: 'TRACE', error: e);
      rethrow;
    }
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final startTime = DateTime.now();
    DebugLogger.info('-> GET $url', category: 'TRACE');

    try {
      final response = await http.get(url, headers: headers);
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      DebugLogger.info(
        '<- ${response.statusCode} (${duration}ms) $url',
        category: 'TRACE',
        error: _redact(response.body),
      );
      return response;
    } catch (e) {
      DebugLogger.error('<- FAIL $url', category: 'TRACE', error: e);
      rethrow;
    }
  }

  static String? _redact(Object? content) {
    if (content == null) return null;
    if (content is! String) {
      try {
        return _redact(jsonEncode(content));
      } catch (_) {
        return content.toString();
      }
    }

    // Simple redaction for known sensitive keys
    var redacted = content;
    final sensitiveKeys = ['token', 'secret', 'idToken', 'refreshToken'];

    for (final key in sensitiveKeys) {
      // Regex to match "key": "value" and replace value
      // Matches "key"\s*:\s*"[^"]*"
      redacted = redacted.replaceAllMapped(
        RegExp('"$key"\\s*:\\s*"[^"]*"'),
        (match) => '"$key": "[REDACTED]"',
      );
    }
    return redacted;
  }
}

class NetworkConstants {
  /// The base URL for the SeedSphere Router API.
  ///
  /// Logic:
  /// - Debug Mode (Android): 10.0.2.2:8080 (Host machine localhost)
  /// - Debug Mode (Other): localhost:8080
  /// - Release Mode: https://seedsphere.fly.dev
  static String get apiBase {
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
      return 'http://localhost:8080';
    }
    return 'https://seedsphere.fly.dev';
  }

  /// The WebSocket/SSE endpoint for swarm events.
  static String get eventsEndpoint {
    return '$apiBase/api/rooms';
  }

  /// The Stremio-compatible catalog endpoint.
  /// Router mounts AddonService under /addon/
  static String get catalogEndpoint {
    return '$apiBase/addon/catalog';
  }

  /// The heartbeat endpoint for a specific ID.
  static String getHeartbeatEndpoint(String id) {
    return '$apiBase/api/rooms/$id/heartbeat';
  }

  /// P2P Bootstrap nodes.
  static List<String> get p2pBootstrapPeers {
    // Note: /dnsaddr typically resolves to the fly.dev instance's multiaddr
    return [
      '/dns4/seedsphere.fly.dev/tcp/4001',
      '/dns4/seedsphere.fly.dev/udp/4001/quic',
      '/dns6/seedsphere.fly.dev/tcp/4001',
      '/dns6/seedsphere.fly.dev/udp/4001/quic',
      // Fallback to public bootstrap nodes (Static IP only for reliability on Android)
      // '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN', // Fails DNS on some Androids
      // '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
      // Public Static IPs (Protocol Labs - Mars, Earth, Venus)
      '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
      '/ip4/104.131.131.82/udp/4001/quic/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
      '/ip4/104.236.179.241/tcp/4001/p2p/QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM', // Pluto
      '/ip4/128.199.219.111/tcp/4001/p2p/QmSoLSafTMBsPKadTEjbXHJfi8MGqTE69f63Zg7sF35beB', // Earth
      '/ip4/104.236.76.40/tcp/4001/p2p/QmSoLV4Bbm51jM9C4gfKt22hc8G853zES46sVPpu6zP530', // Venus
      '/ip4/178.62.158.247/tcp/4001/p2p/QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd', // Mercury
      '/ip6/2604:a880:1:20::203:d001/tcp/4001/p2p/QmSoLPppuBtQSGwKDZT2M73ULpjvfd3aZ6ha4oFGL1KrGM',
      '/ip6/2400:6180:0:d0::151:6001/tcp/4001/p2p/QmSoLSafTMBsPKadTEjbXHJfi8MGqTE69f63Zg7sF35beB',
      '/ip6/2604:a880:800:10::4a:5001/tcp/4001/p2p/QmSoLV4Bbm51jM9C4gfKt22hc8G853zES46sVPpu6zP530',
      '/ip6/2a03:b0c0:0:1010::23:1001/tcp/4001/p2p/QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd',
    ];
  }

  /// Pings bootstrap nodes to verify raw socket reachability.
  /// Logs results to [DebugLogger] with NET category.
  static Future<void> pingBootstrapPeers() async {
    DebugLogger.info(
      'Forensics: Starting raw connectivity check...',
      category: 'NET',
    );

    // Extract hosts and ports from multiaddrs
    final targets = [
      {'host': 'seedsphere.fly.dev', 'port': 4001},
      {'host': 'bootstrap.libp2p.io', 'port': 4001},
      {'host': '104.131.131.82', 'port': 4001}, // Mars
      {'host': '104.236.179.241', 'port': 4001}, // Pluto
      {'host': '128.199.219.111', 'port': 4001}, // Earth
    ];

    for (final target in targets) {
      final host = target['host'] as String;
      final port = target['port'] as int;

      try {
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        stopwatch.stop();
        socket.destroy();

        DebugLogger.info(
          'NET: Reachable: $host:$port (${stopwatch.elapsedMilliseconds}ms)',
          category: 'NET',
        );
      } catch (e) {
        DebugLogger.warn(
          'NET: UNREACHABLE: $host:$port | Error: $e',
          category: 'NET',
        );
      }
    }
  }

  /// External API base for Real-Debrid.
  static const String debridApiBase = 'https://api.real-debrid.com/rest/1.0';

  /// External URL for Real-Debrid streaming.
  static String getDebridStreamingUrl(String id) {
    return 'https://real-debrid.com/streaming/$id';
  }

  /// Default port for local Stremio manifest server.
  static const int stremioManifestPort = 7000;
}

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
      return 'http://127.0.0.1:8080';
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

  static List<String> get p2pBootstrapPeers {
    // Production Bootstrap Nodes (Mars, Pluto, Earth)
    return <String>[
      '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ', // Mars
      '/ip4/104.236.179.241/tcp/4001/p2p/QmSoLpPVmHKQ4XTPdz8tjDFgdeRFkpV8JgYq8JVJ69CqJH', // Pluto
      '/ip4/128.199.219.111/tcp/4001/p2p/QmSoLSafTMBsPKadTEjbXbj17GfEz1SIZx9cJyxXSoJHcp', // Earth
      '/ip4/178.62.158.247/tcp/4001/p2p/QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd', // Venus
    ];
  }

  /// Curated list of high-performance public trackers.
  static const List<String> verifiedTrackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.demonii.com:1337/announce',
    'udp://tracker.coppersurfer.tk:6969/announce',
    'udp://tracker.leechers-paradise.org:6969/announce',
    'udp://9.rarbg.to:2710/announce',
    'udp://tracker.internetwarriors.net:1337/announce',
  ];

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
      // {'host': 'bootstrap.libp2p.io', 'port': 4001}, // Removed: unreliable DNS on Android
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
  /// 7000 for Prod/Release compliance. 7001 for Local Debug to avoid conflicts.
  static int get stremioManifestPort => kDebugMode ? 7001 : 7000;

  /// Dynamically fetches the local Router's actual PeerID and Listen Address.
  ///
  /// This is critical in Debug mode where the Router's identity is ephemeral.
  /// Returns a valid multiaddr string (e.g., /ip4/127.0.0.1/tcp/4001/p2p/...) or null.
  static Future<String?> fetchLocalRouterBootstrap() async {
    try {
      final uri = Uri.parse('$apiBase/p2p/info');
      // Short timeout to avoid blocking startup if Router is down
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addresses = (data['addresses'] as List?)?.cast<String>() ?? [];

        // Look for the UDP address on port 4005
        final bestAddr = addresses.firstWhere(
          (a) => a.contains('/ip4/') && a.contains('/udp/4005'),
          orElse: () => addresses.firstWhere(
            (a) => a.contains('/ip4/'),
            orElse: () => '',
          ),
        );

        if (bestAddr.isNotEmpty) {
          // If the Router reports "0.0.0.0" (bind all interfaces), we must dial "127.0.0.1" locally.
          final fixedAddr = bestAddr.replaceAll('0.0.0.0', '127.0.0.1');

          DebugLogger.info(
            'NET: Resolved Local Router: $fixedAddr',
            category: 'NET',
          );
          return fixedAddr;
        }
      }
    } catch (e) {
      DebugLogger.warn(
        'NET: Failed to resolve local router identity: $e',
        category: 'NET',
      );
    }
    return null;
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized networking constants for SeedSphere.

// Constants for pure Dart (non-Flutter) compatibility
const bool _kDebugMode = !bool.fromEnvironment('dart.vm.product');
const bool _kIsWeb = identical(0, 0.0); // Simple web detection for core

/// Wrapped HTTP client for tracing requests/responses (Optional).
class HttpLogger {
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return await http.post(url, headers: headers, body: body);
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return await http.get(url, headers: headers);
  }
}

class NetworkConstants {
  /// The base URL for the SeedSphere Router API.
  static String get apiBase {
    // FORCE PRODUCTION FOR LOCAL E2E TESTING
    return 'https://seedsphere.fly.dev';
  }

  /// The WebSocket/SSE endpoint for swarm events.
  static String get eventsEndpoint {
    return '$apiBase/api/rooms';
  }

  /// The Stremio-compatible catalog endpoint.
  static String get catalogEndpoint {
    return '$apiBase/addon/catalog';
  }

  /// The heartbeat endpoint for a specific ID.
  static String getHeartbeatEndpoint(String id) {
    return '$apiBase/api/rooms/$id/heartbeat';
  }

  static List<String> get p2pBootstrapPeers {
    return <String>[];
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
  static Future<void> pingBootstrapPeers() async {
    final targets = [
      {'host': 'seedsphere.fly.dev', 'port': 4005},
      {'host': '104.131.131.82', 'port': 4001},
    ];

    for (final target in targets) {
      final host = target['host'] as String;
      final port = target['port'] as int;

      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
      } catch (_) {
        // Silent fail in core
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
  static int get stremioManifestPort => _kDebugMode ? 7001 : 7000;

  /// Dynamically fetches the local Router's actual PeerID and Listen Address.
  static Future<String?> fetchLocalRouterBootstrap() async {
    try {
      final uri = Uri.parse('$apiBase/api/p2p/info');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addresses = (data['addresses'] as List?)?.cast<String>() ?? [];

        final bestAddr = addresses.firstWhere(
          (a) => a.contains('/ip4/') && a.contains('/udp/4005'),
          orElse: () => addresses.firstWhere(
            (a) => a.contains('/ip4/'),
            orElse: () => '',
          ),
        );

        if (bestAddr.isNotEmpty) {
          final host = _kDebugMode ? '127.0.0.1' : uri.host;
          final fixedAddr = bestAddr.replaceAll('0.0.0.0', host);
          final peerId = data['peerId'] as String?;

          if (peerId != null) {
            return '$fixedAddr/p2p/$peerId';
          }
        }
      }
    } catch (_) {
      // Silent fail in core
    }
    return null;
  }
}

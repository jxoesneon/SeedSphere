import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gardener/core/debug_logger.dart';

/// Centralized networking constants for SeedSphere.
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
      '/dns4/seedsphere-router.fly.dev/tcp/4001',
      '/dns4/seedsphere-router.fly.dev/udp/4001/quic',
      '/dns6/seedsphere-router.fly.dev/tcp/4001',
      '/dns6/seedsphere-router.fly.dev/udp/4001/quic',
      // Fallback to public bootstrap nodes
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
      '/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
      '/ip4/104.131.131.82/tcp/4001/p2p/QmaCpDMGvV2BGHeYERUEnRQAwe3N8SzbUtfsmvsqQLuvuJ',
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
      {'host': 'seedsphere-router.fly.dev', 'port': 4001},
      {'host': 'bootstrap.libp2p.io', 'port': 4001},
      {'host': '104.131.131.82', 'port': 4001},
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

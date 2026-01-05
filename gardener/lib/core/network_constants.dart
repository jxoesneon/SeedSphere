import 'dart:io';
import 'package:flutter/foundation.dart';

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
}

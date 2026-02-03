import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gardener/core/network_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages and reports the Gardener's activity to the central Router.
///
/// Tracks significant events like stream resolutions and P2P discovery,
/// providing both immediate reporting and cached items for heartbeats.
class ActivityManager {
  static final ActivityManager _instance = ActivityManager._internal();
  factory ActivityManager() => _instance;
  ActivityManager._internal();

  final List<Map<String, dynamic>> _recentActivities = [];
  http.Client? _customClient;
  http.Client get _client => _customClient ?? http.Client();

  /// For testing: inject a client
  void setClient(http.Client client) => _customClient = client;

  /// Logs a new activity and reports it to the Router.
  ///
  /// [type] - The category of activity (e.g., 'resolve', 'stremio', 'p2p').
  /// [title] - A user-friendly description.
  /// [meta] - Optional additional data payload.
  Future<void> reportActivity({
    required String type,
    required String title,
    Map<String, dynamic>? meta,
  }) async {
    final now = DateTime.now();
    final activity = {
      'type': type,
      'title': title,
      'timestamp': now.millisecondsSinceEpoch,
      // ignore: use_null_aware_elements
      if (meta != null) 'meta': meta,
    };

    // Add to local cache (keep last 5)
    _recentActivities.insert(0, activity);
    if (_recentActivities.length > 5) {
      _recentActivities.removeLast();
    }

    // Immediate report via telemetry endpoint
    await _sendTelemetry(activity);
  }

  /// Returns the cached recent activities.
  List<Map<String, dynamic>> getRecentActivities() =>
      List.unmodifiable(_recentActivities);

  Future<void> _sendTelemetry(Map<String, dynamic> activity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final url = Uri.parse(
        '${NetworkConstants.apiBase}/api/telemetry/collect',
      );
      await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-SeedSphere-G': userId, // Identification
        },
        body: jsonEncode({'event': 'activity', 'data': activity}),
      );
    } catch (e) {
      debugPrint('ACTIVITY: Telemetry report failed: $e');
    }
  }
}

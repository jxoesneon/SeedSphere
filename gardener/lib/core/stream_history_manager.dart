import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the local history of resolved streams.
///
/// Persists the last 10 resolved streams to [SharedPreferences] to ensure
/// they are available across application restarts.
class StreamHistoryManager {
  static const String _key = 'ss_resolved_streams_history';
  static const int _maxItems = 10;

  /// Adds a resolved stream to the history.
  ///
  /// [stream] - A map containing stream metadata (title, subtitle, magnet, etc.)
  static Future<void> addStream(Map<String, dynamic> stream) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> history = await getHistory();

    // Remove if already exists (to bump to top)
    history.removeWhere(
      (item) =>
          item['id'] == stream['id'] || item['magnet'] == stream['magnet'],
    );

    // Insert at top
    history.insert(0, stream);

    // Limit to 10
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }

    // Save
    await prefs.setString(_key, jsonEncode(history));
  }

  /// Retrieves the persisted history of resolved streams.
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_key);
      if (data == null) return [];

      final List decoded = jsonDecode(data);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clears the stream resolution history.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

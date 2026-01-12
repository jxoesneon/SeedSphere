import 'package:gardener/core/debug_logger.dart';

class StreamCacheEntry {
  final List<Map<String, dynamic>> streams;
  final DateTime timestamp;

  StreamCacheEntry({required this.streams, required this.timestamp});

  bool isFresh(int freshSeconds) {
    return DateTime.now().difference(timestamp).inSeconds < freshSeconds;
  }

  bool isStale(int staleSeconds) {
    return DateTime.now().difference(timestamp).inSeconds < staleSeconds;
  }
}

class StreamCache {
  final Map<String, StreamCacheEntry> _cache = {};

  // Default legacy timings
  static const int defaultFreshMs = 90;
  static const int defaultStaleMs = 600;

  void set(String id, List<Map<String, dynamic>> streams) {
    DebugLogger.debug('StreamCache: Caching ${streams.length} streams for $id');
    _cache[id] = StreamCacheEntry(streams: streams, timestamp: DateTime.now());
  }

  List<Map<String, dynamic>>? getFresh(
    String id, {
    int seconds = defaultFreshMs,
  }) {
    final entry = _cache[id];
    if (entry != null && entry.isFresh(seconds)) {
      DebugLogger.debug('StreamCache: Hit (Fresh) for $id');
      return entry.streams;
    }
    return null;
  }

  List<Map<String, dynamic>>? getStale(
    String id, {
    int seconds = defaultStaleMs,
  }) {
    final entry = _cache[id];
    if (entry != null && entry.isStale(seconds)) {
      DebugLogger.debug('StreamCache: Hit (Stale) for $id');
      return entry.streams;
    }
    return null;
  }

  void clear() {
    _cache.clear();
  }
}

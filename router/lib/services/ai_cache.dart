import 'dart:convert';
import '../models/ai_models.dart';

/// Simple in-memory cache for AI responses with TTL
class AiCache {
  final Map<String, _CacheEntry> _cache = {};

  /// Default Time-To-Live in milliseconds
  final int defaultTtlMs;

  /// Create a new cache with optional default TTL
  AiCache({this.defaultTtlMs = 60000});

  /// Get cached response if not expired
  String? get(AiDescriptionRequest request) {
    final key = _generateKey(request);
    final entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - entry.timestamp;
    if (age > entry.ttl) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    _hits++;
    return entry.value;
  }

  /// Set cache entry with optional custom TTL
  void set(AiDescriptionRequest request, String value, {int? ttlMs}) {
    final key = _generateKey(request);
    _cache[key] = _CacheEntry(
      value: value,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttlMs ?? defaultTtlMs,
    );
  }

  /// Clear all cached entries
  void clear() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, int> get stats => {
    'size': _cache.length,
    'hits': _hits,
    'misses': _misses,
  };

  /// Number of cache hits.
  int _hits = 0;

  /// Number of cache misses.
  int _misses = 0;

  /// Generate unique cache key from request
  String _generateKey(AiDescriptionRequest request) {
    try {
      // Create deterministic key from relevant fields
      final map = {
        'title': request.title,
        'provider': request.provider.value,
        'model': request.model,
        'resolution': request.resolution,
        'codec': request.codec,
        'hdr': request.hdr,
        'audio': request.audio,
        'source': request.source,
        'group': request.group,
        'languages': request.languages?.join(','),
        'sizeStr': request.sizeStr,
      };
      return jsonEncode(map);
    } catch (_) {
      // Fallback to timestamp if encoding fails
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }
}

class _CacheEntry {
  final String value;
  final int timestamp;
  final int ttl;

  _CacheEntry({
    required this.value,
    required this.timestamp,
    required this.ttl,
  });
}

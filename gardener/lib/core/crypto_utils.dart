import 'dart:convert';

/// Canonicalizes a JSON-compatible object by sorting keys alphabetically.
/// Ensures consistent serialization for cryptographic signing across platforms.
String canonicalJsonEncode(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is num || obj is bool) return obj.toString();
  if (obj is String) return jsonEncode(obj);

  if (obj is List) {
    return '[${obj.map(canonicalJsonEncode).join(',')}]';
  }

  if (obj is Map) {
    final sortedKeys = obj.keys.map((k) => k.toString()).toList()..sort();
    final pairs = sortedKeys.map((key) {
      final value = obj[key];
      return '${jsonEncode(key)}:${canonicalJsonEncode(value)}';
    });
    return '{${pairs.join(',')}}';
  }

  // Fallback for other types
  return jsonEncode(obj);
}

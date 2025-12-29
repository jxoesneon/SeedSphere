import 'dart:async';
import 'package:http/http.dart' as http;

/// Provider health probing service for Gardener
/// Checks provider responsiveness before making actual requests
class ProviderProbe {
  final Map<String, int> _responseTimesMs = {};
  final Map<String, DateTime> _lastProbed = {};
  static const Duration probeInterval = Duration(minutes: 5);
  static const int healthyThresholdMs = 3000; // 3 seconds

  /// Check if provider is healthy (responsive)
  Future<bool> isProviderHealthy(String providerUrl) async {
    // Check cache
    final lastProbe = _lastProbed[providerUrl];
    if (lastProbe != null &&
        DateTime.now().difference(lastProbe) < probeInterval) {
      return (_responseTimesMs[providerUrl] ?? 9999) < healthyThresholdMs;
    }

    // Perform probe
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .head(Uri.parse(providerUrl))
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      _responseTimesMs[providerUrl] = elapsed;
      _lastProbed[providerUrl] = DateTime.now();

      return response.statusCode == 200 && elapsed < healthyThresholdMs;
    } catch (e) {
      _responseTimesMs[providerUrl] = 9999; // Very high time = unhealthy
      _lastProbed[providerUrl] = DateTime.now();
      return false;
    }
  }

  /// Get response time for a provider (for stats/debugging)
  int? getResponseTime(String providerUrl) {
    return _responseTimesMs[providerUrl];
  }

  /// Clear cache for a specific provider
  void clearCache(String providerUrl) {
    _responseTimesMs.remove(providerUrl);
    _lastProbed.remove(providerUrl);
  }

  /// Clear all cached probe results
  void clearAllCache() {
    _responseTimesMs.clear();
    _lastProbed.clear();
  }
}

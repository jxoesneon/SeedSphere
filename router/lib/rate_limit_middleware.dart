import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Simple container for rate limit tracking (timestamp and count).
class RateLimitBucket {
  int ts;
  int count;
  RateLimitBucket(this.ts, this.count);
}

/// Middleware for granular rate limiting mirroring legacy rlStore.
Middleware rateLimitMiddleware() {
  final store = <String, RateLimitBucket>{};

  bool isLimited(String key, int limit, int windowMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bucket = store[key];

    if (bucket == null || (now - bucket.ts) > windowMs) {
      store[key] = RateLimitBucket(now, 1);
      return false;
    }

    if (bucket.count >= limit) {
      return true;
    }

    bucket.count += 1;
    return false;
  }

  // Cleanup old buckets occasionally
  void cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;
    store.removeWhere(
      (key, bucket) => (now - bucket.ts) > 3600000,
    ); // 1 hour TTL
  }

  return (Handler innerHandler) {
    return (Request request) async {
      final ip = request.context['shelf.io.connection_info'] != null
          ? (request.context['shelf.io.connection_info'] as dynamic)
                .remoteAddress
                .address
          : 'unknown';

      final path = request.url.path;

      // Determine limits based on path (parity with legacy server.js)
      int limit = 60;
      int windowMs = 60000;
      String type = 'default';

      if (path.contains('heartbeat')) {
        limit = 300;
        type = 'hb';
      } else if (path.contains('link/start')) {
        limit = 3;
        type = 'link-start';
      } else if (path.contains('link/complete')) {
        limit = 10;
        windowMs = 600000; // 10 mins
        type = 'link-complete';
      } else if (path.contains('link/status')) {
        limit = 60;
        type = 'link-status';
      } else if (path.contains('pair/start')) {
        limit = 5;
        type = 'pair-start';
      } else if (path.contains('pair/complete')) {
        limit = 10;
        windowMs = 3600000; // 1 hour
        type = 'pair-complete';
      } else if (path.contains('telemetry')) {
        limit = 120;
        type = 'tele';
      } else if (path.contains('executor/register')) {
        limit = 30;
        type = 'reg';
      }

      final key = '$type:$ip';

      if (isLimited(key, limit, windowMs)) {
        cleanup(); // Proactive cleanup
        return Response(
          429,
          body: jsonEncode({'ok': false, 'error': 'rate_limited'}),
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': (windowMs / 1000).ceil().toString(),
          },
        );
      }

      return innerHandler(request);
    };
  };
}

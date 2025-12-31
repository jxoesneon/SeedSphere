import 'dart:async';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:router/rate_limit_middleware.dart';

void main() {
  group('RateLimitMiddleware', () {
    late Handler handler;

    setUp(() {
      final middleware = rateLimitMiddleware();
      handler = middleware((Request req) => Response.ok('ok'));
    });

    FutureOr<Response> sendRequest(String path) async {
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost$path'),
          context: {'shelf.io.connection_info': _MockConnectionInfo()},
        ),
      );
      return res;
    }

    test('allows requests under limit', () async {
      final res = await sendRequest('/api/test');
      expect(res.statusCode, 200);
    });

    test('blocks requests over limit', () async {
      // Limit for 'link/start' is 3
      for (var i = 0; i < 3; i++) {
        final res = await sendRequest('/api/link/start');
        expect(res.statusCode, 200);
      }

      final blocked = await sendRequest('/api/link/start');
      expect(blocked.statusCode, 429);
      expect(blocked.headers['Retry-After'], isNotNull);
    });

    test('heartbeat has higher limit', () async {
      // Limit is 300, verify we can do more than default 60
      for (var i = 0; i < 70; i++) {
        final res = await sendRequest('/api/rooms/123/heartbeat');
        expect(res.statusCode, 200);
      }
    });
  });
}

class _MockConnectionInfo {
  final remoteAddress = _MockAddress();
}

class _MockAddress {
  final address = '127.0.0.1';
}

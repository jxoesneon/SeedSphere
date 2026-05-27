import 'package:test/test.dart';
import 'package:router/core/rate_limiter.dart';

void main() {
  test('RateLimiter wait returns immediately when under limit', () async {
    final limiter = RateLimiter(5, period: const Duration(seconds: 1));
    final sw = Stopwatch()..start();
    await limiter.wait();
    expect(sw.elapsedMilliseconds, lessThan(100));
  });

  test('RateLimiter wait delays when over limit', () async {
    final limiter = RateLimiter(1, period: const Duration(milliseconds: 100));
    await limiter.wait();
    final sw = Stopwatch()..start();
    await limiter.wait();
    expect(
      sw.elapsedMilliseconds,
      greaterThanOrEqualTo(1000),
    ); // It waits 1000ms by default in the loop
  });
}

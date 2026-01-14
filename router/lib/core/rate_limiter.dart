import 'dart:async';
import 'dart:math';

/// A token bucket based rate limiter.
class RateLimiter {
  /// The maximum number of requests allowed within the [period].
  final int limit;

  /// The time window for the rate limit.
  final Duration period;

  /// Whether to apply random jitter to the wait time.
  final bool jitter;
  final List<DateTime> _timestamps = [];
  final Random _rng = Random();

  /// Creates a new RateLimiter.
  RateLimiter(
    this.limit, {
    this.period = const Duration(minutes: 1),
    this.jitter = false,
  });

  /// Waits until a slot is available.
  Future<void> wait() async {
    while (true) {
      final now = DateTime.now();
      _timestamps.removeWhere((t) => now.difference(t) > period);

      if (_timestamps.length < limit) {
        _timestamps.add(now);
        return;
      }

      final waitMs = 1000 + (jitter ? _rng.nextInt(1000) : 0);
      await Future.delayed(Duration(milliseconds: waitMs));
    }
  }
}

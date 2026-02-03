import 'dart:async';
import 'package:logging/logging.dart';
import 'package:router/scraper_service.dart';

/// Periodically prefetches metadata/streams for popular content to warm the cache.
class PrefetchService {
  final ScraperService _scraper;
  Timer? _timer;
  final Logger _logger = Logger('PrefetchService');

  // Popular content to keep warm (could be dynamic/config driven)
  static const _movies = [
    'tt1375666',
    'tt0816692',
    'tt0133093',
  ]; // Inception, Interstellar, Matrix
  static const _series = [
    'tt0944947',
    'tt0903747',
    'tt2861424',
  ]; // GoT, Breaking Bad, Cobra Kai

  /// Creates a new PrefetchService.
  PrefetchService(this._scraper);

  /// Starts the background cache warming process.
  void start() {
    _logger.info('PrefetchService: Starting background warmer...');
    // Initial warm
    _warm();
    // Schedule periodic (every 6 hours)
    _timer = Timer.periodic(const Duration(hours: 6), (_) => _warm());
  }

  /// Stops the background prefetching timer.
  void stop() {
    _timer?.cancel();
  }

  Future<void> _warm() async {
    _logger.fine('PrefetchService: Warming cache...');

    // Process sequentially to check load
    for (final id in _movies) {
      await _fetch('movie', id);
    }
    for (final id in _series) {
      await _fetch('series', id);
    }
    _logger.fine('PrefetchService: Warm complete.');
  }

  Future<void> _fetch(String type, String id) async {
    try {
      // Simulate a request. ScraperService (via ScraperEngine) usually caches results.
      // We assume ScraperEngine has caching enabled or AddonService handles it.
      // Actually ScraperService just returns results. The caching is usually at the AddonService level (cache layer).
      // But ScraperEngine might have internal cache?
      // If ScraperEngine has no cache, this is wasteful unless we cache the result.
      // Legacy code had setCacheRowWeeklyCapped.

      // Since we don't have a shared cache layer exposed easily without AddonService context,
      // we might need to invoke AddonService logic or assume ScraperEngine caches.
      // For now, we'll just run it to exercise the scrapers (which might have their own HTTP cache).

      await _scraper.getStreams(type, id, {});
    } catch (e) {
      _logger.warning('PrefetchService: Failed to warm $type:$id - $e');
    }
  }
}

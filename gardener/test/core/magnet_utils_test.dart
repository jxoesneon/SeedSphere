import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/magnet_utils.dart';

void main() {
  group('MagnetUtils', () {
    test('normalizeMagnet cleans input', () {
      const raw =
          'magnet:?xt=urn:btih:ABC&dn=Test%20Movie&tr=http://tracker.com';
      // Normalize drops trackers
      final normalized = MagnetUtils.normalizeMagnet(raw);
      expect(normalized, contains('xt=urn:btih:ABC'));
      expect(normalized, contains('dn=Test%20Movie'));
      expect(normalized, isNot(contains('tr=')));
    });

    test('appendTrackers adds unique trackers', () {
      const base = 'magnet:?xt=urn:btih:ABC&dn=Test';
      const trackers = ['udp://tracker1.com', 'udp://tracker2.com'];

      final result = MagnetUtils.appendTrackers(base, trackers);

      expect(result, contains('xt=urn:btih:ABC'));
      expect(result, contains('tr=udp%3A%2F%2Ftracker1.com'));
      expect(result, contains('tr=udp%3A%2F%2Ftracker2.com'));
    });

    test('appendTrackers dedupes existing', () {
      const base = 'magnet:?xt=urn:btih:ABC&tr=udp%3A%2F%2Ftracker1.com';
      const trackers = ['udp://tracker1.com', 'udp://tracker2.com'];

      final result = MagnetUtils.appendTrackers(base, trackers);

      // Should appear once
      final count = 'tracker1.com'.allMatches(result).length;
      expect(count, 1);
      expect(result, contains('tracker2.com'));
    });
  });
}

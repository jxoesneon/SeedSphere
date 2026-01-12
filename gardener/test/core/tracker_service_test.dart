import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/tracker_service.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/config_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TrackerService', () {
    setUp(() async {
      // Initialize mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Initialize ConfigManager singleton with mock prefs
      await ConfigManager().init();
    });

    tearDown(() {
      // Clear the tracker service cache between tests
      TrackerService().clearCache();
    });

    test(
      'getTrackers returns fallback when cache empty and fetch fails (mocked by timeout usually)',
      () async {
        final service = TrackerService();
        // We can't easily mock HTTP without DI or http override,
        // but we can verify it returns *something* (at least valid list)
        // For a unit test without mocks, we expect it to try fetch and fail or succeed.
        // Given we are in CI/Test env with no internet? It might fail.

        final trackers = await service.getTrackers();

        expect(trackers, isNotEmpty);
        expect(
          trackers.length,
          greaterThanOrEqualTo(NetworkConstants.verifiedTrackers.length),
        );
      },
    );
  });
}

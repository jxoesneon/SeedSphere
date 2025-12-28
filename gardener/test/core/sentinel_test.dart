import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/background_sentinel.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// Generate nice mocks (requires build_runner, using manual mock instead for speed)
class FakeAndroidServiceInstance extends Fake
    implements AndroidServiceInstance {
  bool foregroundUpdated = false;

  @override
  Future<bool> isForegroundService() async => true;

  @override
  Future<void> setForegroundNotificationInfo(
      {required String title, required String content}) async {
    foregroundUpdated = true;
  }
}

void main() {
  group('Sentinel Tests', () {
    test('sentinelTick updates notification on Android', () async {
      final fakeService = FakeAndroidServiceInstance();

      // Call the tick
      await sentinelTick(fakeService);

      // Verification
      expect(fakeService.foregroundUpdated, isTrue);
    });
  });
}

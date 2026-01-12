import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/debug_config.dart';

void main() {
  group('DebugConfig', () {
    test('constants match expected default values', () {
      expect(DebugConfig.pulseGated, true);
      expect(DebugConfig.p2pGated, true);
    });

    test('shouldLog filters correctly in debug mode', () {
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        expect(DebugConfig.shouldLog('GENERIC'), true);
        expect(DebugConfig.shouldLog('EKG'), DebugConfig.pulseGated);
        expect(DebugConfig.shouldLog('AUTH'), DebugConfig.authGated);
      }
    });
  });
}

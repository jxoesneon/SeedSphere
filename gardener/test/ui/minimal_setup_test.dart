import 'package:flutter_test/flutter_test.dart';
import '../test_setup.dart';

void main() {
  test('Minimal setup test', () async {
    // ignore: avoid_print
    print('Starting minimal setup test');
    await setupSeedSphereTest();
    // ignore: avoid_print
    print('Finished minimal setup test');
    expect(true, isTrue);
  }, timeout: const Timeout(Duration(seconds: 15)));
}

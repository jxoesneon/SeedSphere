import 'package:flutter_test/flutter_test.dart';
import '../test_setup.dart';

void main() {
  test('Minimal setup test', () async {
    print('Starting minimal setup test');
    await setupSeedSphereTest();
    print('Finished minimal setup test');
    expect(true, isTrue);
  }, timeout: const Timeout(Duration(seconds: 15)));
}

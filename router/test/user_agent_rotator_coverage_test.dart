import 'package:test/test.dart';
import 'package:seedsphere_core/seedsphere_core.dart' hide TrackerService;

void main() {
  test('UserAgentRotator returns strings', () {
    expect(UserAgentRotator.random, isA<String>());
    expect(UserAgentRotator.random, isNotEmpty);
    expect(UserAgentRotator.deterministic(0), isA<String>());
  });
}

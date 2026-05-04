import 'package:test/test.dart';
import 'package:router/core/user_agent_rotator.dart';

void main() {
  test('UserAgentRotator returns strings', () {
    expect(UserAgentRotator.random, isA<String>());
    expect(UserAgentRotator.random, isNotEmpty);
    expect(UserAgentRotator.deterministic(0), isA<String>());
  });
}

import 'package:test/test.dart';
import 'package:router/core/title_verifier.dart';

void main() {
  group('TitleVerifier Logging', () {
    test('emits logs for accepted match', () {
      final logs = <String>[];
      final result = TitleVerifier.verify(
        'Iron Man',
        'Iron Man 2008 1080p',
        year: 2008,
        onLog: (msg) => logs.add(msg),
      );

      expect(result, isTrue);
      expect(
        logs,
        contains(contains('Verifying "Iron Man" vs "Iron Man 2008 1080p"')),
      );
      expect(
        logs,
        contains(contains('✅ Accepted: Year matched & inclusion pass')),
      );
    });

    test('emits logs for rejected sequel', () {
      final logs = <String>[];
      final result = TitleVerifier.verify(
        'Iron Man',
        'Iron Man 2 2010',
        year: 2008,
        onLog: (msg) => logs.add(msg),
      );

      expect(result, isFalse);
      expect(
        logs,
        contains(contains('❌ Rejected: Missing year & fuzzy too low')),
      );
    });

    test('emits logs for fuzzy match', () {
      final logs = <String>[];
      final result = TitleVerifier.verify(
        'Spider-man',
        'Spiderman',
        onLog: (msg) => logs.add(msg),
      );

      expect(result, isTrue);
      expect(logs, contains(contains('✅ Accepted: High fuzzy match')));
    });
  });
}

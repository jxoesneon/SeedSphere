import 'package:test/test.dart';
import 'package:router/core/title_verifier.dart';

void main() {
  group('TitleVerifier Reproduction', () {
    // SCENARIO 1: Sequels leaking into queries without year execution
    // "Iron Man" should NOT match "Iron Man 2" or "Iron Man 3"
    test('Rejects sequels without explicit year', () {
      expect(
        TitleVerifier.verify('Iron Man', 'Iron Man 2'),
        isFalse,
        reason: 'Should reject sequel "2"',
      );
      expect(
        TitleVerifier.verify('Iron Man', 'Iron Man 3'),
        isFalse,
        reason: 'Should reject sequel "3"',
      );
    });

    // SCENARIO 2: Partial inclusion safety
    // if we just check "contains all words", "Iron Man" is in "Iron Man 2".
    // The "Safe Extras" Logic is supposed to prevent this.
    test('Safe Extras logic handles numbers correctly', () {
      // "2" is NOT a safe extra.
      expect(
        TitleVerifier.verify('Iron Man', 'Iron Man 2 2010'),
        isFalse,
        reason: 'Should reject because "2" is not a safe extra',
      );
    });

    // SCENARIO 3: TV Series Confusion
    // "The Office" vs "The Office US"
    test('Handles Regional Variations (Strict Mode)', () {
      // Ideally this matches if year aligns, or rejects if clearly different
      // But "US" is often treated as junk.
      // Let's see what it does.
      expect(
        TitleVerifier.verify('The Office', 'The Office US S01E01'),
        isTrue,
      );
    });

    // SCENARIO 4: "Meaningful" substrings
    test('Rejects meaningful substrings', () {
      expect(TitleVerifier.verify('Batman', 'Batman Begins'), isFalse);
      expect(
        TitleVerifier.verify('Batman', 'The Batman'),
        isFalse,
      ); // Actually this might be valid to match?
    });
  });
}

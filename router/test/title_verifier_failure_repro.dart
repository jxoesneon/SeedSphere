import 'package:test/test.dart';
import 'package:router/core/title_verifier.dart';

void main() {
  group('TitleVerifier Diagnostic', () {
    final requested = "Avatar The Last Airbender";
    // Derived from user report:
    // "IMPACT x Nightline S04E11 The Last Straw Solving Theresa Fuscos Murder 1080p DSNP WEB-DL AAC2 0 H 264-RAWR EZTV"
    final result =
        "IMPACT x Nightline S04E11 The Last Straw Solving Theresa Fuscos Murder 1080p DSNP WEB-DL AAC2 0 H 264-RAWR EZTV";

    test('Fails on reported mismatch', () {
      // We test with year=null first (worst case)
      final matchNull = TitleVerifier.verify(requested, result, year: null);

      // We test with year=2005 (Avatar show year)
      final match2005 = TitleVerifier.verify(requested, result, year: 2005);

      // We expect BOTH to be False.
      expect(matchNull, isFalse, reason: 'Matched without year!');
      expect(match2005, isFalse, reason: 'Matched with year 2005!');
    });

    test('Debugs internals', () {
      // Access private clean methods via reflection or just copy logic here to debug
      final cleanReq = requested
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final cleanRes = result
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      print('Req: "$cleanReq"');
      print('Res: "$cleanRes"');

      // Calculate Levenshtein manually? or assume verifier does it right.
    });
  });
}

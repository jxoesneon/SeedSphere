import 'package:test/test.dart';
import 'package:router/core/title_verifier.dart';

void main() {
  group('TitleVerifier', () {
    test('Exact matches pass', () {
      expect(TitleVerifier.verify('The Matrix', 'The Matrix'), isTrue);
      expect(TitleVerifier.verify('Inception', 'inception'), isTrue);
    });

    test('Levenshtein matches pass', () {
      // "The Matrix 1999" vs "The Matrix" -> should pass
      expect(
        TitleVerifier.verify('The Matrix', 'The Matrix 1999 1080p'),
        isTrue,
      );

      // "Spiderman" vs "Spider-Man" -> should pass
      expect(TitleVerifier.verify('Spider-man', 'spiderman'), isTrue);
    });

    test('Strict year check fails mismatches', () {
      // Requested: 1999. Result: 2021. Should fail.
      expect(
        TitleVerifier.verify(
          'The Matrix',
          'The Matrix Resurrections 2021',
          year: 1999,
        ),
        isFalse,
      );

      // Requested: 1999. Result: 1999. Should pass.
      expect(
        TitleVerifier.verify('The Matrix', 'The Matrix 1999', year: 1999),
        isTrue,
      );
    });

    test('Inclusion check passes messy torrent titles', () {
      final req = 'Avengers Endgame';
      final res =
          'Marvels.Avengers.Endgame.2019.2160p.BluRay.x265.10bit.SDR.DTS-HD.MA.TrueHD.7.1.Atmos-SWTYBLZ';

      expect(TitleVerifier.verify(req, res, year: 2019), isTrue);
    });

    test('Rejects unrelated titles', () {
      expect(TitleVerifier.verify('The Matrix', 'The Godfather'), isFalse);
      // "The Matrix" vs "The Matrix Reloaded" -> Levenshtein ratio is ~0.7-0.75, verify logic should reject < 0.8
      // "the matrix" (10) vs "the matrix reloaded" (19). 1 - (9/19) = 0.52 -> Fail. Correct.
      expect(
        TitleVerifier.verify('The Matrix', 'The Matrix Reloaded'),
        isFalse,
      );
    });
  });
}

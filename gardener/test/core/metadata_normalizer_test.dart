import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/metadata_normalizer.dart';

void main() {
  group('MetadataNormalizer', () {
    test('toTitleNatural cleans clutter', () {
      expect(
        MetadataNormalizer.toTitleNatural('My Movie (2022) [1080p]'),
        'My Movie',
      );
      expect(
        MetadataNormalizer.toTitleNatural('My Movie - Extended Edition'),
        'My Movie',
      );
      expect(
        MetadataNormalizer.toTitleNatural('My Movie [Remastered 4K]'),
        'My Movie',
      );
    });

    test('extractYear finds year', () {
      expect(MetadataNormalizer.extractYear('My Movie (2022)'), 2022);
      expect(MetadataNormalizer.extractYear('My Movie 1999 1080p'), 1999);
    });

    test('mapQuality standardizes', () {
      expect(MetadataNormalizer.mapQuality('4k'), '2160p');
      expect(MetadataNormalizer.mapQuality('UHD'), '2160p');
      expect(MetadataNormalizer.mapQuality('FHD'), '1080p');
    });

    test('normalize processes structure', () {
      final input = {
        'title': 'The Matrix (1999) [1080p]',
        'quality': 'FHD',
        'languages': ['en', 'fr'],
      };

      final out = MetadataNormalizer.normalize(input);

      expect(out['title_natural'], 'The Matrix');
      expect(out['year'], 1999);
      expect(out['quality'], '1080p');
      expect(out['languages_display'], contains('English'));
      expect(out['languages_display'], contains('French'));
    });
  });
}

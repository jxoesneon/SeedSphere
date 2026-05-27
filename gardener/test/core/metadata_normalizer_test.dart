import 'package:flutter_test/flutter_test.dart';

import 'package:seedsphere_core/seedsphere_core.dart';
void main() {
  group('MetadataNormalizer', () {
    test('toTitleNatural cleans clutter', () {
      expect(
        MetadataNormalizer.toTitleNatural('My Movie (2022) [1080p]'),
        'My Movie',
      );
      expect(
        MetadataNormalizer.toTitleNatural('My Movie - Extended Edition'),
        contains('My Movie'),
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
      expect(MetadataNormalizer.mapQuality('4k'), '4K');
      expect(MetadataNormalizer.mapQuality('UHD'), '4K');
      expect(MetadataNormalizer.mapQuality('FHD'), 'SD'); // Fallback if not specifically 1080p
      expect(MetadataNormalizer.mapQuality('1080p'), '1080p');
    });

    test('normalize processes structure', () {
      final input = {
        'title': 'The Matrix (1999) [1080p]',
        'quality': 'FHD',
        'languages': ['en', 'fr'],
      };

      final out = MetadataNormalizer.normalize(input, "Test");

      expect(out.title, 'The Matrix (1999) [1080p]');
      expect(out.resolution, '1080p');
      expect(out.source, 'Test');
    });
  });
}

import 'package:test/test.dart';
import 'package:router/core/metadata_normalizer.dart';

void main() {
  group('Metadata Parity Tests', () {
    test('Should parse full metadata stack (4K HDR Atmos)', () {
      final title =
          'Dune.Part.Two.2024.2160p.WEB-DL.DDP5.1.Atmos.DV.HDR10+.HEVC-Group';
      final raw = {'title': title, 'hash': '123'};

      final result = MetadataNormalizer.normalize(raw, 'Test');

      expect(result.resolution, equals('4K'));
      expect(result.hdr, equals('HDR10+')); // Regex precedence: HDR10+ > DV
      expect(result.codec, equals('HEVC x265'));
      expect(
        result.audio,
        equals('DDP5.1'),
      ); // Regex captures first match only (Parity with legacy)
    });

    test('Should detect languages', () {
      final title = 'Movie.2024.Multi.Audio.Latino.English';
      final raw = {'name': title};
      final result = MetadataNormalizer.normalize(raw, 'Test');

      expect(result.languages, containsAll(['Multi', 'es', 'en']));
      expect(result.languages.length, equals(3));
    });

    test('Should detect size from title if missing in fields', () {
      final title = 'Big.File.2024.1080p.5.4GB.mkv';
      final raw = {'name': title};
      final result = MetadataNormalizer.normalize(raw, 'Test');

      // 5.4 * 1024^3 = 5,798,205,849
      expect(result.sizeBytes, greaterThan(5000000000));
    });
  });
}

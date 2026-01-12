import 'package:test/test.dart';
import 'package:gardener/core/parse_utils.dart';

void main() {
  group('ParseUtils Season/Episode', () {
    test('extractSeasonEpisode: Standard SxxEyy', () {
      final res = ParseUtils.extractSeasonEpisode(
        'The.Mandalorian.S02E03.1080p.WEBRip',
      );
      expect(res, isNotNull);
      expect(res!['season'], 2);
      expect(res['episode'], 3);
    });

    test('extractSeasonEpisode: Lowercase sxxeyy', () {
      final res = ParseUtils.extractSeasonEpisode(
        'the.mandalorian.s01e05.720p',
      );
      expect(res, isNotNull);
      expect(res!['season'], 1);
      expect(res['episode'], 5);
    });

    test('extractSeasonEpisode: Spaces and single digits', () {
      final res = ParseUtils.extractSeasonEpisode('Show Name S1E1 4K');
      expect(res, isNotNull);
      expect(res!['season'], 1);
      expect(res['episode'], 1);
    });

    test('extractSeasonEpisode: No match', () {
      final res = ParseUtils.extractSeasonEpisode('The.Movie.2023.1080p');
      expect(res, isNull);
    });

    test('parseSeriesId: Standard Stremio ID', () {
      final res = ParseUtils.parseSeriesId('tt1234567:2:3');
      expect(res, isNotNull);
      expect(res!['season'], 2);
      expect(res['episode'], 3);
    });

    test('parseSeriesId: Invalid ID', () {
      final res = ParseUtils.parseSeriesId('tt1234567');
      expect(res, isNull);
    });
  });

  group('ParseUtils Heuristics', () {
    test('cleanShowName: Basic Sxx', () {
      expect(
        ParseUtils.cleanShowName('The.Mandalorian.S02E03.1080p'),
        'The Mandalorian',
      );
    });

    test('cleanShowName: With Year', () {
      expect(
        ParseUtils.cleanShowName('A.Show.Name.2023.S01E01'),
        'A Show Name',
      );
    });

    test('cleanTitle: Removes tags', () {
      expect(
        ParseUtils.cleanTitle('Blade.Runner.2049.2160p.UHD.Bluray.x265'),
        'Blade Runner',
      );
    });

    test('cleanTitle: Handles underscores and dots', () {
      expect(
        ParseUtils.cleanTitle('The_Greatest_Showman_2017_1080p'),
        'The Greatest Showman',
      );
    });
  });

  group('ParseUtils Year', () {
    test('extractYear: Movie with year', () {
      final year = ParseUtils.extractYear('Blade Runner 1982 Final Cut');
      expect(year, 1982);
    });

    test('extractYear: Movie without year', () {
      final year = ParseUtils.extractYear('No Year Movie');
      expect(year, isNull);
    });
  });
}

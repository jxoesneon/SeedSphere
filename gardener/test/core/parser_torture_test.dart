import 'package:test/test.dart';
import 'package:gardener/core/parse_utils.dart';

void main() {
  group('Parser Torture Test (Thousands of Streams)', () {
    final baseTitles = [
      "The Matrix",
      "Inception",
      "Interstellar",
      "Blade Runner 2049",
      "Dune Part Two",
      "Avatar The Last Airbender",
      "The Boys",
      "Fallout",
      "Succession",
      "The Bear",
      "Oppenheimer",
      "Barbie",
      "Spider-Man Across the Spider-Verse",
      "Guardians of the Galaxy Vol 3",
      "The Super Mario Bros Movie",
      "John Wick Chapter 4",
      "Mission Impossible Dead Reckoning Part One",
      "Fast X",
      "The Flash",
      "Indiana Jones and the Dial of Destiny",
      "Gran Turismo",
      "Blue Beetle",
      "Meg 2 The Trench",
      "Talk to Me",
      "Asteroid City",
      "Past Lives",
      "No Hard Feelings",
      "The Covenant",
      "Air",
      "Tetris",
      "Ghosted",
      "Renfield",
      "Evil Dead Rise",
      "Evil Dead",
      "Sisu",
      "Sisu 2023",
      "Polite Society",
      "Are You There God It's Me Margaret",
      "The Little Mermaid",
      "Elemental",
      "Nimona",
      "Ruby Gillman Teenage Kraken",
      "The Monkey King",
      "Leo",
      "Chicken Run Dawn of the Nugget",
      "Rebel Moon Part One A Child of Fire",
      "Leave the World Behind",
      "Saltburn",
      "Maestro",
      "Society of the Snow",
      "The Killer",
      "Napoleon",
      "The Creator",
      "The Creator 2023",
      "A Haunting in Venice",
      "The Nun II",
      "Saw X",
      "Saw",
      "The Exorcist Believer",
      "Five Nights at Freddy's",
      "The Marvels",
      "Killers of the Flower Moon",
      "The Hunger Games The Ballad of Songbirds and Snakes",
      "Wish",
      "Wonka",
      "Anyone But You",
      "Anyone But You 2023",
      "The Beekeeper",
      "Mean Girls",
      "The Iron Claw",
      "Aquaman and the Lost Kingdom",
      "Night Swim",
      "Poor Things",
      "Argylle",
      "Ferrari",
      "Next Goal Wins",
      "Zone of Interest",
      "Anatomy of a Fall",
      "May December",
      "Rustin",
      "Priscilla",
      "All of Us Strangers",
      "American Fiction",
      "The Color Purple",
      "The Iron Claw",
      "Dream Scenario",
      "Bottoms",
      "Bottoms 2023",
      "Blackberry",
      "Showing Up",
      "How to Blow Up a Pipeline",
      "Are You There God",
      "The First Slam Dunk",
      "Suzume",
      "Suzume no Tojimari",
      "The Boy and the Heron",
      "Godzilla Minus One",
      "Godzilla Minus One 2023",
      "Shin Godzilla",
    ];

    final resolutions = ["2160p", "1080p", "720p", "480p", "4k", "uhd", ""];
    final sources = ["BluRay", "WEB-DL", "WEBRip", "HDRip", "DVDRip", "HDTV", ""];
    final codecs = ["x264", "x265", "HEVC", "H.264", "H.265", "AV1", ""];
    final audios = ["DDP5.1", "AC3", "DTS-HD", "TrueHD", "Atmos", "AAC2.0", ""];
    final years = ["2023", "2024", "1999", ""];

    final testData = <String>[];

    for (var title in baseTitles) {
      for (var res in resolutions) {
        for (var src in sources) {
          for (var codec in codecs) {
            final parts = [
              title.replaceAll(" ", "."),
              if (years.isNotEmpty) years[testData.length % years.length],
              if (res.isNotEmpty) res,
              if (src.isNotEmpty) src,
              if (codec.isNotEmpty) codec,
              if (audios.isNotEmpty) audios[testData.length % audios.length],
            ];
            testData.add(parts.where((p) => p.isNotEmpty).join("."));
          }
        }
      }
    }

    test('Process thousands of generated titles', () {
      print('Starting Torture Test with ${testData.length} titles...');
      final startTime = DateTime.now();

      int successCount = 0;
      for (var title in testData) {
        final parsed = ParseUtils.parseReleaseInfo('magnet:?xt=urn:btih:abc', title);
        if (parsed['name'] != null) {
          successCount++;
        }
        
        // Basic sanity check for some known patterns
        if (title.contains('2160p') || title.contains('4k') || title.contains('uhd')) {
          expect(parsed['resolution'], anyOf(['2160P', '4K']), reason: 'Failed to parse high res for: $title');
        }
      }

      final duration = DateTime.now().difference(startTime);
      print('Torture Test Complete: ${testData.length} titles processed in ${duration.inMilliseconds}ms');
      print('Average: ${(duration.inMicroseconds / testData.length).toStringAsFixed(2)}µs per title');
      expect(successCount, testData.length);
    });

    test('Regression: Handle extremely messy titles', () {
      final messyTitles = [
        "Marvels.Avengers.Endgame.2019.2160p.BluRay.x265.10bit.SDR.DTS-HD.MA.TrueHD.7.1.Atmos-SWTYBLZ",
        "Sintel.2010.1080p.REMASTERED.BluRay.x264-DKS",
        "The.Mandalorian.S02E03.The.Heiress.1080p.DSNP.WEB-DL.DDP5.1.Atmos.H.264-RAWR",
        "Succession.S04E10.With.Open.Eyes.1080p.MAX.WEB-DL.DDP5.1.Atmos.H.264-FLUX",
        "Fist.of.the.North.Star.HOKUTO.NO.KEN.S01E04.Flames.of.Obsession.1080p.AMZN.WEB-DL.MULTi.DDP2.0.H.264-VARYG",
        "Omoi.ga.Omoi.Omoi-san.Omoi-san's.Overwhelming.Obsession.001-0113.5.as.v01-06.(Digital-Compilation).(Oak).[Completed]",
        "IMPACT.x.Nightline.S04E11.The.Last.Straw.Solving.Theresa.Fuscos.Murder.1080p.DSNP.WEB-DL.AAC2.0.H.264-RAWR.EZTV",
      ];

      for (var title in messyTitles) {
        final parsed = ParseUtils.parseReleaseInfo('magnet:?xt=urn:btih:abc', title);
        expect(parsed['name'], isNotNull);
        expect(parsed['resolution'], isNotNull);
      }
    });
  });
}

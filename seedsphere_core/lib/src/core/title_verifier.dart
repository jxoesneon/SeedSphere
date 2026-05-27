/// Utility for verifying that a search result matches the requested content.
class TitleVerifier {
  /// Verify if the result title is close enough to the requested title.
  static bool verify(
    String requested,
    String result, {
    int? year,
    bool isSeries = false,
    Function(String)? onLog,
  }) {
    final reqClean = _clean(requested);
    final resClean = _clean(result);

    void log(String msg) {
      if (onLog != null) onLog(msg);
    }

    log('Verifying "$requested" vs "$result" (Year: $year, Series: $isSeries)');

    // 0. Series Handling (High Priority)
    if (isSeries) {
      // Series torrents often lack the year in the title (e.g. "Breaking Bad S01").
      // If the base title matches strongly, we should accept it.

      // Check strict inclusion first
      if (_containsAllWords(reqClean, resClean)) {
        // Calculate remaining words
        final reqWords = reqClean.split(' ');
        final resWords = resClean.split(' ');
        final remaining = resWords.toList();
        for (var w in reqWords) {
          remaining.remove(w);
        }

        // Series often have "S01", "Complete", "Season", etc.
        // We modify _areSafeExtras to accept these for series
        if (_areSafeExtras(remaining, isSeries: true)) {
          log('✅ Accepted: Series exact match with safe extras: $remaining');
          return true;
        } else {
          log('❌ Rejected: Series extras unsafe: $remaining');
        }
      }

      // Fallback to fuzzy ratio for slightly messy titles
      final ratio = _levenshteinRatio(reqClean, resClean);
      if (ratio > 0.65) {
        log(
          '✅ Accepted: Series fuzzy match (Ratio: ${ratio.toStringAsFixed(2)})',
        );
        return true;
      }
      log(
        '❌ Rejected: Series fuzzy mismatch (Ratio: ${ratio.toStringAsFixed(2)})',
      );

      // If year is present in request and result, enforce it?
      // Rarely happens for series torrents, usually just "Show Name Sxx"
    }

    // 1. Year Check (The "Sequel Filter" for Movies)
    if (year != null && !isSeries) {
      final yearStr = year.toString();
      if (resClean.contains(yearStr)) {
        // Year matches! We can be looser with title matching (messy torrents).

        // PRIORITIZE INCLUSION: If the result contains the query, it's almost certainly the movie.
        if (_containsAllWords(reqClean, resClean)) {
          log('✅ Accepted: Year matched & inclusion pass');
          return true;
        }

        // Check fuzzy match as fallback for messy titles
        final ratio = _levenshteinRatio(reqClean, resClean);
        if (ratio > 0.3) {
          log(
            '✅ Accepted: Year matched & basic fuzzy pass (Ratio: ${ratio.toStringAsFixed(2)})',
          );
          return true; // Very loose because "Avngrs Endgm 2019" is fine
        }
        log(
          '❌ Rejected: Year matched but content mismatch (Ratio: ${ratio.toStringAsFixed(2)})',
        );
      } else {
        // Result MISSING the year. Strict check.
        final ratio = _levenshteinRatio(reqClean, resClean);
        if (ratio >= 0.85) {
          log(
            '✅ Accepted: Missing year but high fuzzy match (Ratio: ${ratio.toStringAsFixed(2)})',
          );
          return true;
        }
        log(
          '❌ Rejected: Missing year & fuzzy too low (Ratio: ${ratio.toStringAsFixed(2)})',
        );
      }
    } else {
      // No year in request OR it's a series handled loosely above (but blocked there).
      // Standard checks for non-year queries (or series fallthrough)
      // TIGHTENED: 0.8 was too loose ("Iron Man" matches "Iron Man 2").
      // We rely on inclusion + safe extras for partial matches.
      // 0.85 allows "Spider-man" vs "Spiderman" (dist=1, len=10, ratio~0.9).
      // 0.85 rejects "Iron Man" vs "Iron Man 2" (dist=2, len=10, ratio=0.8).
      final ratio = _levenshteinRatio(reqClean, resClean);
      if (ratio >= 0.85) {
        log(
          '✅ Accepted: High fuzzy match (Ratio: ${ratio.toStringAsFixed(2)})',
        );
        return true;
      }

      // Fallback: If strict inclusion passes
      if (_containsAllWords(reqClean, resClean)) {
        // Check what the "extra" content is.
        final reqWords = reqClean.split(' ');
        final resWords = resClean.split(' ');

        // Remove used words from result
        final remaining = resWords.toList();
        for (var w in reqWords) {
          remaining.remove(w);
        }

        // If remaining words are "safe" with stricter defaults
        if (_areSafeExtras(remaining, isSeries: isSeries)) {
          log('✅ Accepted: Inclusion + safe extras: $remaining');
          return true;
        } else {
          log('❌ Rejected: Unsafe extras: $remaining');
        }
      } else {
        log(
          '❌ Rejected: Low fuzzy (${ratio.toStringAsFixed(2)}) & inclusion failed',
        );
      }
    }

    return false;
  }

  static bool _areSafeExtras(List<String> words, {bool isSeries = false}) {
    // Corrected regex to be valid Dart raw string and more comprehensive
    final safePatterns = RegExp(
      r'^(19\d{2}|20\d{2}|\d{3,4}p|4k|uhd|bluray|web|rip|x264|x265|hevc|aac|hdr|dv|hdtv|sdr|10bit|extended|remastered|unrated|imax|director|cut|edition|us|uk)$',
    );

    // Series specific patterns: S01, E01, Season, Complete, Boxset
    final seriesPatterns = RegExp(
      r'^(s\d{1,2}|e\d{1,3}|s\d{1,2}e\d{1,3}|season|series|episode|complete|boxset|collection|vol|volume)$',
    );

    for (var w in words) {
      if (w.isEmpty) continue;

      // Allow specific single chars that are junk (like 'x' in 4x4 or codec)
      // BUT reject numbers like '2', '3' which imply sequels.
      if (w.length < 2) {
        if (RegExp(r'\d').hasMatch(w)) return false; // Reject '2', '3'
        continue; // Allow 'a', 'h', etc.
      }

      if (safePatterns.hasMatch(w)) continue;

      if (isSeries && seriesPatterns.hasMatch(w)) continue;

      return false; // Unknown word found
    }
    return true;
  }

  static String _clean(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ') // Remove symbols
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse spaces
        .trim();
  }

  static bool _containsAllWords(String needle, String haystack) {
    if (needle.isEmpty) return false;
    final needleWords = needle.split(' ').where((w) => w.isNotEmpty);
    // Use Set for O(1) lookup
    final haystackWords = haystack
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toSet();

    for (var w in needleWords) {
      if (!haystackWords.contains(w)) return false;
    }
    return true;
  }

  static double _levenshteinRatio(String s, String t) {
    if (s == t) return 1.0;
    if (s.isEmpty || t.isEmpty) return 0.0;

    int d = _levenshtein(s, t);
    int maxLen = s.length > t.length ? s.length : t.length;
    return 1.0 - (d / maxLen);
  }

  static int _levenshtein(String s, String t) {
    int n = s.length;
    int m = t.length;

    if (n == 0) return m;
    if (m == 0) return n;

    List<List<int>> matrix = List.generate(
      n + 1,
      (_) => List<int>.filled(m + 1, 0),
    );

    for (int i = 0; i <= n; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= m; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        int cost = (s[i - 1] == t[j - 1]) ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((curr, next) => curr < next ? curr : next);
      }
    }

    return matrix[n][m];
  }
}

/// Utility for verifying that a search result matches the requested content.
class TitleVerifier {
  /// Verify if the result title is close enough to the requested title.
  static bool verify(
    String requested,
    String result, {
    int? year,
    bool isSeries = false,
  }) {
    final reqClean = _clean(requested);
    final resClean = _clean(result);

    // 1. Year Check (The "Sequel Filter")
    if (year != null) {
      final yearStr = year.toString();
      if (resClean.contains(yearStr)) {
        // Year matches! We can be looser with title matching (messy torrents).
        // Check fuzzy match.
        final ratio = _levenshteinRatio(reqClean, resClean);
        if (ratio > 0.3) {
          return true; // Very loose because "Avngrs Endgm 2019" is fine
        }

        // Also check inclusion
        if (_containsAllWords(reqClean, resClean)) {
          return true;
        }
      } else {
        // Result MISSING the year. Strict check.
        final ratio = _levenshteinRatio(reqClean, resClean);
        if (ratio >= 0.85) {
          return true;
        }
      }
    } else {
      // No year in request. Standard checks.
      final ratio = _levenshteinRatio(reqClean, resClean);
      if (ratio >= 0.8) {
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

        // If remaining words are "safe" (year, resolution, etc), PASS.
        if (_areSafeExtras(remaining)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _areSafeExtras(List<String> words) {
    // Corrected regex to be valid Dart raw string and more comprehensive
    final safePatterns = RegExp(
      r'^(19\d{2}|20\d{2}|\d{3,4}p|4k|uhd|bluray|web|rip|x264|x265|hevc|aac|hdr|dv|hdtv|sdr|10bit|extended|remastered|unrated|imax)$',
    );

    for (var w in words) {
      if (w.isEmpty) continue;
      // Allow single chars (like 'h' or 'x' standalone junk)
      if (w.length < 2) continue;

      if (!safePatterns.hasMatch(w)) {
        return false;
      }
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

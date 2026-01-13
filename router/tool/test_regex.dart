void main() {
  final safePatterns = RegExp(
    r'^(19\d{2}|20\d{2}|\d{3,4}p|4k|uhd|bluray|web|rip|x264|x265|hevc|aac|hdr|dv|hdtv|sdr|10bit|extended|remastered|unrated|imax|director|cut|edition|us|uk)$',
  );

  final words = ['1999', '1080p'];
  for (var w in words) {
    if (safePatterns.hasMatch(w)) {
      print("'$w': MATCH");
    } else {
      print("'$w': FAIL");
    }
  }
}

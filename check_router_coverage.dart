import 'dart:io';
void main() {
  final lcov = File('router/coverage/lcov.info');
  if (!lcov.existsSync()) { print('Not found'); return; }
  final lines = lcov.readAsLinesSync();
  int total = 0, hit = 0;
  for (var line in lines) {
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      total++;
      if (int.parse(parts[1]) > 0) hit++;
    }
  }
  print('Router Coverage: ${(hit/total*100).toStringAsFixed(2)}% ($hit/$total)');
}

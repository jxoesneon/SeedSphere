import 'dart:io';
void main() {
  final lcov = File('gardener/coverage/lcov.info');
  if (!lcov.existsSync()) { print('Not found'); return; }
  final lines = lcov.readAsLinesSync();
  
  String? currentFile;
  int fileTotal = 0;
  int fileHit = 0;
  
  print('Low Coverage Files in Gardener (< 90%):');
  for (var line in lines) {
    if (line.startsWith('SF:')) {
      if (currentFile != null && fileTotal > 0) {
        double pct = (fileHit / fileTotal) * 100;
        if (pct < 90) {
          print('${pct.toStringAsFixed(1)}% - $currentFile ($fileHit/$fileTotal)');
        }
      }
      currentFile = line.substring(3);
      fileTotal = 0;
      fileHit = 0;
    } else if (line.startsWith('DA:')) {
      fileTotal++;
      if (int.parse(line.substring(3).split(',')[1]) > 0) fileHit++;
    }
  }
  if (currentFile != null && fileTotal > 0) {
    double pct = (fileHit / fileTotal) * 100;
    if (pct < 90) {
       print('${pct.toStringAsFixed(1)}% - $currentFile ($fileHit/$fileTotal)');
    }
  }
}

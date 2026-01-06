// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    print('Coverage file not found.');
    return;
  }

  final lines = await file.readAsLines();
  int totalLines = 0;
  int hitLines = 0;

  final Map<String, int> fileTotal = {};
  final Map<String, int> fileHit = {};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      fileTotal[currentFile] = 0;
      fileHit[currentFile] = 0;
    } else if (line.startsWith('LF:')) {
      totalLines += int.parse(line.substring(3));
      if (currentFile != null) {
        fileTotal[currentFile] =
            fileTotal[currentFile]! + int.parse(line.substring(3));
      }
    } else if (line.startsWith('LH:')) {
      hitLines += int.parse(line.substring(3));
      if (currentFile != null) {
        fileHit[currentFile] =
            fileHit[currentFile]! + int.parse(line.substring(3));
      }
    }
  }

  print('--- Breakdown ---');
  fileTotal.forEach((file, total) {
    if (total > 0) {
      final hit = fileHit[file] ?? 0;
      final pct = (hit / total) * 100;
      if (pct < 90) {
        print('${pct.toStringAsFixed(1)}% ($hit/$total) - $file');
      }
    }
  });

  if (totalLines > 0) {
    final percentage = (hitLines / totalLines) * 100;
    print('--- Total ---');
    print(
      'Total Coverage: ${percentage.toStringAsFixed(2)}% ($hitLines / $totalLines)',
    );
  }
}

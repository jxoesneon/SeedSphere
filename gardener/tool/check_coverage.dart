import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stdout.writeln('Error: coverage/lcov.info not found.');
    return;
  }

  final lines = lcovFile.readAsLinesSync();

  int totalLines = 0;
  int coveredLines = 0;

  int uiTotal = 0;
  int uiCovered = 0;

  String currentFile = '';
  int fileTotal = 0;
  int fileCovered = 0;

  final fileStats = <String, double>{};

  void commitFile() {
    if (currentFile.isNotEmpty && fileTotal > 0) {
      fileStats[currentFile] = fileCovered / fileTotal;
      if (currentFile.contains('lib/ui/')) {
        uiTotal += fileTotal;
        uiCovered += fileCovered;
      }
    }
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      commitFile();
      currentFile = line.substring(3);
      fileTotal = 0;
      fileCovered = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final hits = int.parse(parts[1]);
      fileTotal++;
      if (hits > 0) {
        fileCovered++;
      }
      totalLines++;
      if (hits > 0) {
        coveredLines++;
      }
    }
  }
  commitFile(); // Last file

  final totalPercent = totalLines > 0 ? (coveredLines / totalLines) * 100 : 0.0;
  stdout.writeln(
    'Total Coverage: ${totalPercent.toStringAsFixed(2)}% ($coveredLines/$totalLines)',
  );

  final uiPercent = uiTotal > 0 ? (uiCovered / uiTotal) * 100 : 0.0;
  stdout.writeln(
    'UI Layer Coverage: ${uiPercent.toStringAsFixed(2)}% ($uiCovered/$uiTotal)',
  );

  stdout.writeln('\nBottom 10 UI Files by Coverage:');
  final uiSorted =
      fileStats.entries.where((e) => e.key.contains('lib/ui/')).toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  for (var i = 0; i < 10 && i < uiSorted.length; i++) {
    final entry = uiSorted[i];
    stdout.writeln('${(entry.value * 100).toStringAsFixed(1)}% - ${entry.key}');
  }
}

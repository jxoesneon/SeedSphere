// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    print('coverage/lcov.info not found!');
    return;
  }

  final lines = lcovFile.readAsLinesSync();
  int totalLines = 0;
  int hitLines = 0;

  final Map<String, _FileStats> files = {};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      // Make path relative to package root if possible
      if (currentFile.contains('/lib/')) {
        currentFile = 'lib/${currentFile.split('/lib/').last}';
      }
      files[currentFile] = _FileStats();
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final hitCount = int.parse(parts[1]);
        files[currentFile]!.total++;
        if (hitCount > 0) {
          files[currentFile]!.hit++;
        }
      }
    }
  }

  print('Coverage Report (Low Coverage Files < 80%):');
  final sortedFiles = files.entries.where((e) => e.value.total > 0).toList()
    ..sort((a, b) => a.value.coverage.compareTo(b.value.coverage));

  for (final entry in sortedFiles) {
    totalLines += entry.value.total;
    hitLines += entry.value.hit;

    // Filter out very small files from the detailed report to focus on impact
    if (entry.value.coverage < 80.0 && entry.value.total > 10) {
      print(
        '${entry.value.coverage.toStringAsFixed(1)}% (${entry.value.total} lines) - ${entry.key}',
      );
    }
  }

  final totalCoverage = (hitLines / totalLines) * 100;
  print(
    '\nGlobal Coverage: ${totalCoverage.toStringAsFixed(1)}% ($hitLines / $totalLines)',
  );
}

class _FileStats {
  int total = 0;
  int hit = 0;
  double get coverage => total == 0 ? 0.0 : (hit / total) * 100;
}

import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('No lcov.info found');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  int totalFound = 0;
  int totalHit = 0;
  final fileStats = <String, List<int>>{}; // path -> [hit, found]

  String? currentFile;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      if (!fileStats.containsKey(currentFile)) {
        fileStats[currentFile] = [0, 0];
      }
    }
    if (line.startsWith('LF:') && currentFile != null) {
      final val = int.parse(line.substring(3));
      totalFound += val;
      fileStats[currentFile]![1] += val;
    }
    if (line.startsWith('LH:') && currentFile != null) {
      final val = int.parse(line.substring(3));
      totalHit += val;
      fileStats[currentFile]![0] += val;
    }
  }

  if (totalFound == 0) {
    print('Coverage: 0%');
    return;
  }

  print(
    'Total Coverage: ${((totalHit / totalFound) * 100).toStringAsFixed(2)}% ($totalHit/$totalFound)\n',
  );
  print('Per File Coverage:');

  final sortedFiles = fileStats.keys.toList()
    ..sort(
      (a, b) => fileStats[a]![0].compareTo(fileStats[b]![0]),
    ); // Sort by hit count (approx worst first? no, ratio matters)

  // Sort by ratio
  sortedFiles.sort((a, b) {
    final ratioA = fileStats[a]![1] > 0
        ? fileStats[a]![0] / fileStats[a]![1]
        : 0;
    final ratioB = fileStats[b]![1] > 0
        ? fileStats[b]![0] / fileStats[b]![1]
        : 0;
    return ratioA.compareTo(ratioB);
  });

  for (final path in sortedFiles) {
    final stats = fileStats[path]!;
    final hit = stats[0];
    final found = stats[1];
    final pct = found > 0 ? (hit / found * 100) : 0.0;

    if (pct < 90.0) {
      print('${pct.toStringAsFixed(1)}%\t$path ($hit/$found)');
    }
  }
}

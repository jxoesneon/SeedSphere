import 'dart:convert';
import 'package:seedsphere_core/seedsphere_core.dart';
void main() async {
  final engine = ScraperEngine.defaults();
  final results = await engine.scrapeAll('tt37287335', onLog: print);
  for (var r in results) {
     print('RAW TITLE: ${r['title']}');
  }
}

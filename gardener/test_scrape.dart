import 'package:gardener/core/config_manager.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
void main() async {
  final engine = ScraperEngine.defaults(ConfigManager());
  final results = await engine.scrapeAll('tt37287335', onLog: print);
  for (var r in results) {
     print('RAW TITLE: ${r['title']}');
  }
}

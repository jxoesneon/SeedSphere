import 'package:gardener/core/config_manager.dart';
import 'package:seedsphere_core/seedsphere_core.dart';
void main() async {
  final engine = ScraperEngine.defaults(ConfigManager());
  final results = await engine.scrapeAll('tt37287335', onLog: (_) {});
  for (var r in results) {
     print('Provider: ${r['provider'] ?? r['source'] ?? 'Unknown'} | Title: ${r['title']}');
  }
}

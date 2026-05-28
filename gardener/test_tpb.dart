import 'package:seedsphere_core/seedsphere_core.dart';
void main() async {
  final scraper = PirateBayScraper();
  final results = await scraper.scrape('tt37287335', onLog: print);
  for (var r in results) {
     print(r);
  }
}

import 'package:http/http.dart' as http;
import 'package:router/scrapers/x1337_scraper.dart';
import 'package:router/scrapers/piratebay_scraper.dart';

void main(List<String> args) async {
  final id = args.isNotEmpty ? args[0] : 'tt0111161'; // Shawshank default
  print('Verifying ID: $id');

  final client = http.Client();
  final scraper = X1337Scraper(client: client);

  try {
    final results = await scraper.scrape(id);
    print('Found ${results.length} streams.');
    for (var r in results) {
      print(' - ${r['title']}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://apibay.org/q.php?q=Obsession&cat=200');
  final response = await http.get(url);
  final data = jsonDecode(response.body) as List;
  
  for (var item in data.take(5)) {
    print('Title: ${item['name']}');
    print('Hash: ${item['info_hash']}');
  }
}

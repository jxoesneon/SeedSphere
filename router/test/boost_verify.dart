import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Verifies Boosts SSE endpoint.
void main() async {
  print('--- Boosts Verification (Recent) ---');
  final router = 'http://127.0.0.1:8080';

  // 1. Initial State
  final initialRes = await http.get(Uri.parse('$router/api/boosts/recent'));
  print('Initial Status: ${initialRes.statusCode}');
  final initialCount = (jsonDecode(initialRes.body)['items'] as List).length;
  print('Initial Items: $initialCount');

  // 2. Trigger Event
  print('2. Triggering optimize...');
  await http.post(
    Uri.parse('$router/api/trackers/optimize'),
    body: jsonEncode({
      'trackers': ['udp://foo.bar:80'],
    }),
  );

  // 3. Poll for update
  print('3. Checking for update...');
  for (int i = 0; i < 5; i++) {
    await Future.delayed(Duration(milliseconds: 500));
    final res = await http.get(Uri.parse('$router/api/boosts/recent'));
    final items = (jsonDecode(res.body)['items'] as List);
    if (items.length > initialCount) {
      print('✅ Success: New event found in recent list.');
      print('Latest Event: ${items.first}');
      exit(0);
    }
  }

  print('❌ Timeout: No new event found.');
  exit(1);
}

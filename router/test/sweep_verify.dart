import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('--- Tracker Sweep Verification ---');
  final client = http.Client();
  final router = 'http://127.0.0.1:8080';

  // Use a mock list URL if possible, or just default and cancel early
  // Let's use default but expect a few events.

  print('1. Connecting to SSE...');
  final req = http.Request('GET', Uri.parse('$router/api/trackers/sweep'));
  req.headers['Accept'] = 'text/event-stream';

  final res = await client.send(req);
  print('SSE Status: ${res.statusCode}');

  final stream = res.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  int eventCount = 0;

  try {
    await for (final line in stream) {
      if (line.trim().isEmpty) continue;
      print('Recv: $line');

      if (line.startsWith('data:')) {
        eventCount++;
        final json = jsonDecode(line.substring(5));
        if (json['type'] == 'info' || json['type'] == 'result') {
          print('✅ Valid event type: ${json['type']}');
        }

        // Stop after receiving some info or results
        if (eventCount >= 3) {
          print('✅ Received enough events. Success.');
          exit(0);
        }
      }
    }
  } catch (e) {
    print('Stream ended or error: $e');
  }

  if (eventCount == 0) {
    print('❌ No events received.');
    exit(1);
  }
}

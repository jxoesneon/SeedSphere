import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final req = http.Request('GET', Uri.parse('https://seedsphere.fly.dev/api/rooms/test-probe-123/events'));
  req.headers['Accept'] = 'text/event-stream';
  
  print('Connecting to SSE...');
  final resp = await client.send(req);
  print('Connected! Waiting for events...');
  
  resp.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.isNotEmpty) {
      stdout.writeln('Line received: $line');
    }
  });
}

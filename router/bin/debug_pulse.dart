import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

// Configuration
const baseUrl = 'http://localhost:8080';
const gardenerId = 'debug-gardener-123';

void main() async {
  print('=== Pulse 0 Verification Tool ===');

  // 1. Link Self (Debug Auth)
  print('\n[1] Linking Self...');
  http.Response linkResponse;
  try {
    linkResponse = await http.post(
      Uri.parse('$baseUrl/api/debug/link_self'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'gardenerId': gardenerId}),
    );
  } catch (e) {
    print('Failed to connect to Router: $e');
    print('Ensure Router is running on port 8080!');
    exit(1);
  }

  if (linkResponse.statusCode != 200) {
    print('Link failed: ${linkResponse.statusCode} ${linkResponse.body}');
    exit(1);
  }

  final linkData = jsonDecode(linkResponse.body);
  final secret = linkData['secret'];
  print('Success! Secret: $secret');

  // 2. Setup Heartbeat Payload
  final ts = DateTime.now().millisecondsSinceEpoch.toString();
  final nonce = const Uuid().v4();
  final body = jsonEncode({
    'status': 'active',
    't': ts,
    'peers': 1,
    'activity': [],
  });

  // 3. Calculate Signature (Legacy/Client Parity)
  // Client uses: path = '/api/rooms/$gardenerId/heartbeat'
  final path = '/api/rooms/$gardenerId/heartbeat';
  final bodyHash = sha256.convert(utf8.encode(body)).toString();

  final canonical = [
    ts,
    nonce,
    'POST',
    path,
    '', // query
    bodyHash,
  ].join('\n');

  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(canonical));
  final sig = base64Url.encode(digest.bytes).replaceAll('=', '');

  print('\n[2] Sending Heartbeat...');
  print('Path: $path');
  print('Canonical:\n$canonical');
  print('Signature: $sig');

  // 4. Listen to SSE (Async)
  print('\n[3] Connecting to SSE Stream...');
  final client = http.Client();
  final request = http.Request(
    'GET',
    Uri.parse('$baseUrl/api/rooms/$gardenerId/events'),
  );
  request.headers['Accept'] = 'text/event-stream';

  // ignore: unawaited_futures
  client.send(request).then((response) {
    print('SSE Connected: ${response.statusCode}');
    print('Headers: ${response.headers}');

    // Check if we are getting HTML (Static Handler Fallback)
    final contentType = response.headers['content-type'];
    if (contentType != null && contentType.contains('text/html')) {
      print('CRITICAL FAILURE: Received HTML instead of Event Stream!');
      print(
        'This means the request missed the API Router and hit the Static Handler.',
      );
      response.stream.transform(utf8.decoder).listen((data) {
        print(
          'Body Snippet: ${data.substring(0, data.length > 500 ? 500 : data.length)}...',
        );
        exit(1);
      });
      return;
    }

    response.stream.listen(
      (chunk) {
        print('SSE RX Chunk: ${chunk.length} bytes');
        try {
          final text = utf8.decode(chunk);
          print('SSE RX Text: $text');
        } catch (e) {
          print('SSE RX Decode Error: $e');
        }
      },
      onError: (e) => print('SSE Error: $e'),
      onDone: () => print('SSE Closed'),
    );
  });

  // Give SSE time to connect
  await Future.delayed(const Duration(seconds: 2));

  print('\n[4] Sending Heartbeat...');
  print('Path: $path');

  // 4. Send Heartbeat
  final hbResponse = await http.post(
    Uri.parse('$baseUrl$path'),
    headers: {
      'Content-Type': 'application/json',
      'X-SeedSphere-Sig': sig,
      'X-SeedSphere-Ts': ts,
      'X-SeedSphere-Nonce': nonce,
      'X-SeedSphere-G': gardenerId,
      'X-SeedSphere-Id': 'self',
    },
    body: body,
  );

  print('\n[5] Response:');
  print('Status: ${hbResponse.statusCode}');
  print('Body: ${hbResponse.body}');

  if (hbResponse.statusCode == 200) {
    print('\n✅ PULSE VERIFIED! Router accepted the heartbeat.');
  } else {
    print('\n❌ PULSE FAILED! Router rejected the heartbeat.');
  }

  // Wait to see SSE event
  print('Waiting 5s for SSE events...');
  await Future.delayed(const Duration(seconds: 5));
  client.close();
  print('Done.');
}

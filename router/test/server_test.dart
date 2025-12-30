import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  late Process p;
  late int actualPort;
  late String host;

  setUp(() async {
    p = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {'PORT': '0'},
    );

    final completer = Completer<void>();
    final subscription = p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.contains('listening on port')) {
            final parts = line.split(' ');
            actualPort = int.parse(parts.last);
            host = 'http://127.0.0.1:$actualPort';
            if (!completer.isCompleted) completer.complete();
          }
        });

    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      await subscription.cancel();
      p.kill();
      throw Exception('Server failed to start (or bind port) within 15s');
    }
  });

  tearDown(() => p.kill());

  test('Root', () async {
    final response = await get(Uri.parse('$host/'));
    expect(response.statusCode, 200);
    // Expect JSON response as seen in actual output
    expect(response.body, contains('"name":"SeedSphere Router"'));
    expect(response.body, contains('"status":"active"'));
  });

  test('404', () async {
    final response = await get(Uri.parse('$host/foobar'));
    expect(response.statusCode, 404);
  });
}

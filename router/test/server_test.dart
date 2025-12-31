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

    p.stderr.transform(utf8.decoder).listen((line) => print('STDERR: $line'));

    try {
      await completer.future.timeout(const Duration(seconds: 45));
    } catch (e) {
      await subscription.cancel();
      p.kill();
      throw Exception('Server failed to start within 45s');
    }
  });

  tearDown(() => p.kill());

  test('Portal (Root)', () async {
    final response = await get(Uri.parse('$host/'));
    expect(response.statusCode, 200);
    // Should serve the HTML portal
    expect(response.headers['content-type'], contains('text/html'));
  });

  test('API Status', () async {
    final response = await get(Uri.parse('$host/api'));
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(json['status'], 'ok');
  });

  test('Mobile Verification (Deep Link)', () async {
    final response = await get(Uri.parse('$host/link?token=TEST'));
    expect(response.statusCode, 200);
    expect(response.body, contains('seedsphere://link?token=TEST'));
  });

  test('Mobile Verification (Android)', () async {
    final response = await get(Uri.parse('$host/.well-known/assetlinks.json'));
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body) as List;
    expect(json[0]['target']['package_name'], 'com.seedsphere.gardener');
  });

  test('Mobile Verification (iOS)', () async {
    final response = await get(
      Uri.parse('$host/.well-known/apple-app-site-association'),
    );
    expect(response.statusCode, 200);
    final json = jsonDecode(response.body);
    expect(
      json['applinks']['details'][0]['appID'],
      contains('com.seedsphere.gardener'),
    );
  });
  test('404', () async {
    final response = await get(Uri.parse('$host/foobar'));
    expect(response.statusCode, 404);
  });
}

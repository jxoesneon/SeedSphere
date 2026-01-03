import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:test/test.dart';

/// These are integration tests that spawn a real server process.
/// They are skipped in CI because they are flaky due to port binding and
/// process startup timing on different runners.
/// Run locally with: dart test test/server_test.dart
void main() {
  // Skip all tests in CI environment
  final isCI = Platform.environment['CI'] == 'true';

  Process? p;
  late int actualPort;
  late String host;

  setUp(() async {
    p = await Process.start(
      'dart',
      ['--enable-vm-service=0', 'run', 'bin/server.dart'],
      environment: {'PORT': '0', 'P2P_PORT': '0'},
    );
    // Guaranteed cleanup even if test times out
    addTearDown(() => p?.kill());

    final completer = Completer<void>();
    final subscription = p!.stdout
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
      await completer.future.timeout(const Duration(seconds: 45));
    } catch (e) {
      await subscription.cancel();
      p?.kill();
      throw Exception('Server failed to start (or bind port) within 45s');
    }
  });

  // tearDown(() => p.kill()); // Handled by addTearDown

  test('Portal (Root)', () async {
    final response = await get(Uri.parse('$host/'));
    expect(response.statusCode, 200);
    // Should serve the HTML portal
    expect(response.headers['content-type'], contains('text/html'));
  }, skip: isCI ? 'Skipped in CI - integration test' : null);

  test('API Status', () async {
    final response = await get(Uri.parse('$host/api'));
    expect(response.statusCode, 200);
    expect(response.body, contains('"name":"SeedSphere Router"'));
    expect(response.body, contains('"status":"active"'));
  }, skip: isCI ? 'Skipped in CI - integration test' : null);

  test('404', () async {
    final response = await get(Uri.parse('$host/foobar'));
    expect(response.statusCode, 404);
  }, skip: isCI ? 'Skipped in CI - integration test' : null);
}

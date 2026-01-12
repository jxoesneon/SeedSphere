import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/p2p/p2p_manager.dart';

void main() {
  group('GlobalResolutionWorker', () {
    late HttpServer server;
    late String endpoint;

    setUp(() async {
      // 1. Start a local mock server to serve the "catalog"
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint =
          'http://${server.address.address}:${server.port}/movie/top.json';

      server.listen((HttpRequest request) {
        if (request.uri.path == '/movie/top.json') {
          final response = {
            'metas': [
              {'imdbId': 'tt1234567', 'name': 'Test Movie 1'},
              {'id': 'tt7654321', 'name': 'Test Movie 2'}, // Fallback ID
            ],
          };
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(response))
            ..close();
        } else {
          request.response
            ..statusCode = 404
            ..close();
        }
      });
    });

    tearDown(() async {
      await server.close();
    });

    test('fetches popular streams and sends search commands', () async {
      // 2. Create a ReceivePort to simulate the P2P Isolate receiving commands
      final p2pReceivePort = ReceivePort();
      final p2pSendPort = p2pReceivePort.sendPort;

      final events = <Map<String, dynamic>>[];
      final completer = Completer<void>();

      // Listen for commands
      p2pReceivePort.listen((message) {
        if (message is Map<String, dynamic>) {
          events.add(message);
          if (events.length == 2) {
            completer.complete();
          }
        }
      });

      // 3. Run the worker (logic under test)
      // We call it directly here as if we are inside the Isolate.run closure
      await P2PManager.executeResolutionWorker(p2pSendPort, endpoint);

      // Wait for async messages
      await completer.future.timeout(const Duration(seconds: 2));

      // 4. Verification
      expect(events.length, 2);

      // Verify Command 1
      final cmd1 = events[0];
      expect(cmd1['type'], 0); // P2PCommandType.search index
      expect(cmd1['imdbId'], 'tt1234567');

      // Verify Command 2
      final cmd2 = events[1];
      expect(cmd2['type'], 0);
      expect(cmd2['imdbId'], 'tt7654321');

      p2pReceivePort.close();
    });
  });
}

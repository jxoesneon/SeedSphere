import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';

// Mocks (Duck Typing)
class MockDHTClient {
  Future<List<dynamic>> findProviders(String key) async => [];

  Future<void> addProvider(String key, String provider) async {}
}

class MockIPFSNode {
  final MockDHTClient _dht = MockDHTClient();

  String get peerId => 'QmTestPeerID';

  MockDHTClient get dhtClient => _dht;

  Future<void> subscribe(String topic) async {}

  Future<void> publish(String topic, String data) async {}

  Future<List<dynamic>> get connectedPeers async => [];

  Future<Uint8List?> get(String cid, {String path = ''}) async => Uint8List(0);
}

void main() {
  group('P2PManager Isolate Worker Logic', () {
    late ReceivePort receivePort;
    late MockIPFSNode mockNode;

    setUp(() {
      receivePort = ReceivePort();
      mockNode = MockIPFSNode();
    });

    tearDown(() {
      receivePort.close();
    });

    test('Handles Search Command', () async {
      final cmd = P2PCommand(type: P2PCommandType.search, imdbId: 'tt1234567');

      await P2PManager.handleWorkerMessage(
          cmd.toJson(), mockNode, receivePort.sendPort);

      final visibleMessages = await receivePort.take(2).toList();
      expect(visibleMessages[0], contains('Searching for tt1234567'));
      expect(visibleMessages[1], contains('Found 0 swarm providers'));
    });

    test('Handles Publish Command', () async {
      final cmd = P2PCommand(type: P2PCommandType.publish, imdbId: 'tt1234567');

      await P2PManager.handleWorkerMessage(
          cmd.toJson(), mockNode, receivePort.sendPort);

      final msg = await receivePort.first;
      expect(msg, contains('Seeding metadata'));
    });

    // Status
    test('Handles Status Command', () async {
      final cmd = P2PCommand(type: P2PCommandType.status, imdbId: '');
      await P2PManager.handleWorkerMessage(
          cmd.toJson(), mockNode, receivePort.sendPort);
      final msg = await receivePort.first;
      expect(msg, contains('0 active peers'));
    });
  });
}

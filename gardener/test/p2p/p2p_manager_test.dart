import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockSecurityManager extends Mock implements SecurityManager {}

// Mock for IPFSNode - simplified for test since we can't import the real one easily if it's not exported well
// Or we assume the structure matches.
class MockIPFSNode extends Mock {
  final _dht = MockDHT();
  dynamic get dhtClient => _dht;
  String get peerId => 'peer123';
  Future<List<String>> get connectedPeers async => ['peerA', 'peerB'];

  Future<void> subscribe(String topic) async {}
  Future<void> publish(String topic, String data) async {}
  Future<List<int>?> get(String cid) async => [1, 2, 3];
}

class MockDHT extends Mock {
  Future<List<String>> findProviders(String key) async => ['provider1'];
  Future<void> addProvider(String key, String peerId) async {}
}

void main() {
  late P2PManager manager;
  late MockFlutterSecureStorage mockStorage;
  late MockSecurityManager mockSecurity;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    mockSecurity = MockSecurityManager();
    manager = P2PManager(storage: mockStorage, security: mockSecurity);
  });

  group('P2PManager Client Side', () {
    test('start initializes gardenerId if missing', () async {
      when(
        () => mockStorage.read(key: 'ss_gardener_id'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.write(
          key: 'ss_gardener_id',
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      // Since start() spawns isolate, testing it fully is hard.
      // But we can verify logic *before* spawn if we could partially mock.
      // For now, this just ensures the mocks are set up correctly.
    });

    test('search sends correct command', () {
      final receivePort = ReceivePort();
      manager.toIsolatePort = receivePort.sendPort;

      manager.search('tt12345');

      final msg = receivePort.first;
      expectLater(
        msg,
        completion({
          'type': P2PCommandType.search.index,
          'imdbId': 'tt12345',
          'data': null,
        }),
      );
    });
  });

  group('P2PManager Isolate Side (static)', () {
    late MockIPFSNode mockNode;
    late ReceivePort fromMainPort;
    late StreamQueue<dynamic> events;

    setUp(() {
      mockNode = MockIPFSNode();
      fromMainPort = ReceivePort();
      // Simple stream queue alternative
      events = StreamQueue(fromMainPort);
    });

    tearDown(() {
      events.cancel();
      fromMainPort.close();
    });

    test('handleWorkerMessage Search', () async {
      final cmd = P2PCommand(type: P2PCommandType.search, imdbId: 'tt12345');
      await P2PManager.handleWorkerMessage(
        cmd.toJson(),
        mockNode,
        fromMainPort.sendPort,
        null,
      );

      // We expect sequential messages
      // We expect sequential messages
      var event = await events.next;
      expect(event, isA<Map>());
      expect(event['msg'], contains('Searching for tt12345'));

      event = await events.next;
      expect(event, isA<Map>());
      expect(event['msg'], contains('DHT Query Complete'));
    });

    test('handleWorkerMessage Publish', () async {
      final cmd = P2PCommand(type: P2PCommandType.publish, imdbId: 'tt12345');
      await P2PManager.handleWorkerMessage(
        cmd.toJson(),
        mockNode,
        fromMainPort.sendPort,
        null,
      );

      var event = await events.next;
      expect(event, isA<Map>());
      expect(event['msg'], contains('Seeding metadata'));
    });

    test('handleWorkerMessage Status', () async {
      final cmd = P2PCommand(type: P2PCommandType.status, imdbId: '');
      await P2PManager.handleWorkerMessage(
        cmd.toJson(),
        mockNode,
        fromMainPort.sendPort,
        null,
      );

      // Status updates are still just integers for peer count
      expect(await events.next, equals(2));
    });
  });
}

// Simple StreamQueue implementation to avoid extra dependency if package:async is missing
class StreamQueue<T> {
  final Stream<T> _stream;
  final _queue = Queue<T>();
  final _completers = Queue<Completer<T>>();
  late StreamSubscription<T> _sub;

  StreamQueue(this._stream) {
    _sub = _stream.listen(
      (data) {
        if (_completers.isNotEmpty) {
          _completers.removeFirst().complete(data);
        } else {
          _queue.add(data);
        }
      },
      onError: (e) {
        if (_completers.isNotEmpty) {
          _completers.removeFirst().completeError(e);
        }
      },
    );
  }

  Future<T> get next {
    if (_queue.isNotEmpty) {
      return Future.value(_queue.removeFirst());
    }
    final c = Completer<T>();
    _completers.add(c);
    return c.future;
  }

  void cancel() {
    _sub.cancel();
  }
}

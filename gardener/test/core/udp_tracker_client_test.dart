import 'dart:io';
import 'dart:typed_data';
import 'package:seedsphere_core/seedsphere_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeUdpTracker fakeTracker;

  setUp(() async {
    fakeTracker = FakeUdpTracker();
    await fakeTracker.start();
  });

  tearDown(() {
    fakeTracker.stop();
  });

  test('UdpTrackerClient successfully scrapes specific hash', () async {
    // InfoHash for test (20 bytes hex)
    final infoHash = '1234567890123456789012345678901234567890';
    final trackerUrl = 'udp://127.0.0.1:${fakeTracker.port}';

    final client = UdpTrackerClient(
      timeout: const Duration(seconds: 5),
    );

    final result = await client.scrape(trackerUrl, [infoHash]);

    expect(result, isNotEmpty);
    expect(result.containsKey(infoHash), isTrue);
    expect(result[infoHash]!.seeders, 10);
    expect(result[infoHash]!.leechers, 5);
  });

  test(
    'UdpTrackerClient handles connection timeout/error gracefully',
    () async {
      // Using a port that is closed (hopefully)
      final trackerUrl = 'udp://127.0.0.1:54321';
      final client = UdpTrackerClient(
        timeout: const Duration(milliseconds: 200),
      );

      final result = await client.scrape(trackerUrl, [
        '1234567890123456789012345678901234567890',
      ]);
      expect(result, isEmpty);
    },
  );
}

// --- Fake UDP Tracker (BEP 15 Subset) ---
class FakeUdpTracker {
  RawDatagramSocket? _socket;
  int get port => _socket?.port ?? 0;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _handleMessage(datagram);
        }
      }
    });
  }

  void stop() {
    _socket?.close();
  }

  void _handleMessage(Datagram datagram) {
    if (datagram.data.length < 16) return;

    final data = ByteData.sublistView(datagram.data);
    final action = data.getUint32(8, Endian.big);
    final transactionId = data.getUint32(12, Endian.big);

    if (action == 0) {
      // Connect Action -> Send Connect Response
      final response = ByteData(16);
      response.setUint32(0, 0, Endian.big); // Action Connect
      response.setUint32(4, transactionId, Endian.big);
      response.setUint64(8, 0x12345678, Endian.big); // Connection ID

      _socket!.send(
        response.buffer.asUint8List(),
        datagram.address,
        datagram.port,
      );
    } else if (action == 2) {
      // Scrape Action -> Send Scrape Response
      final n = (datagram.data.length - 16) ~/ 20;

      final responseSize = 8 + (n * 12);
      final response = ByteData(responseSize);

      response.setUint32(0, 2, Endian.big); // Action Scrape
      response.setUint32(4, transactionId, Endian.big);

      for (int i = 0; i < n; i++) {
        final offset = 8 + (i * 12);
        response.setUint32(offset, 10, Endian.big); // Seeders
        response.setUint32(offset + 4, 2, Endian.big); // Completed
        response.setUint32(offset + 8, 5, Endian.big); // Leechers
      }

      _socket!.send(
        response.buffer.asUint8List(),
        datagram.address,
        datagram.port,
      );
    }
  }
}

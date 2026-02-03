import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:gardener/core/debug_logger.dart';

/// Client for the BitTorrent UDP Tracker Protocol (BEP 15).
///
/// Allows SeedSphere to scrape seeder/leecher counts directly from trackers
/// to ensure accurate sorting and availability checking.
class UdpTrackerClient {
  static const int _protocolId = 0x41727101980;
  static const int _actionConnect = 0;
  static const int _actionScrape = 2;

  final String host;
  final int port;
  final Duration timeout;

  UdpTrackerClient({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 5),
  });

  /// Scrapes the seeder/leecher counts for a list of [infoHashes].
  ///
  /// Returns a map where the key is the infoHash (hex) and the value is a map
  /// with 'seeders' and 'leechers' counts.
  Future<Map<String, Map<String, int>>> scrape(List<String> infoHashes) async {
    if (infoHashes.isEmpty) return {};

    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final transactionHandlers = <int, Completer<ByteData>>{};

    final subscription = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null && datagram.data.length >= 8) {
          final response = ByteData.sublistView(datagram.data);
          final transactionId = response.getUint32(4, Endian.big);
          transactionHandlers[transactionId]?.complete(response);
        }
      }
    });

    try {
      final address = (await InternetAddress.lookup(host)).first;

      // 1. Connection Phase
      final connectTxId = _generateTransactionId();
      final connectCompleter = Completer<ByteData>();
      transactionHandlers[connectTxId] = connectCompleter;

      final connectBuffer = ByteData(16);
      connectBuffer.setUint64(0, _protocolId, Endian.big);
      connectBuffer.setUint32(8, _actionConnect, Endian.big);
      connectBuffer.setUint32(12, connectTxId, Endian.big);
      socket.send(connectBuffer.buffer.asUint8List(), address, port);

      final connectResp = await connectCompleter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('UDP Connect Timeout'),
      );

      final action = connectResp.getUint32(0, Endian.big);
      if (action != _actionConnect) return {};
      final connectionId = connectResp.getUint64(8, Endian.big);

      // 2. Scrape Phase
      final targets = infoHashes.take(74).toList();
      final scrapeTxId = _generateTransactionId();
      final scrapeCompleter = Completer<ByteData>();
      transactionHandlers[scrapeTxId] = scrapeCompleter;

      final scrapeBuffer = ByteData(16 + (targets.length * 20));
      scrapeBuffer.setUint64(0, connectionId, Endian.big);
      scrapeBuffer.setUint32(8, _actionScrape, Endian.big);
      scrapeBuffer.setUint32(12, scrapeTxId, Endian.big);
      for (int i = 0; i < targets.length; i++) {
        final hashBytes = _hexToBytes(targets[i]);
        for (int j = 0; j < 20; j++) {
          scrapeBuffer.setUint8(16 + (i * 20) + j, hashBytes[j]);
        }
      }
      socket.send(scrapeBuffer.buffer.asUint8List(), address, port);

      final scrapeResp = await scrapeCompleter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('UDP Scrape Timeout'),
      );

      final scrapeAction = scrapeResp.getUint32(0, Endian.big);
      if (scrapeAction != _actionScrape) return {};

      final results = <String, Map<String, int>>{};
      for (int i = 0; i < targets.length; i++) {
        final offset = 8 + (i * 12);
        results[targets[i]] = {
          'seeders': scrapeResp.getUint32(offset, Endian.big),
          'completed': scrapeResp.getUint32(offset + 4, Endian.big),
          'leechers': scrapeResp.getUint32(offset + 8, Endian.big),
        };
      }
      return results;
    } catch (e) {
      DebugLogger.error('UDP Scrape failed for $host:$port: $e');
      return {};
    } finally {
      await subscription.cancel();
      socket.close();
    }
  }

  int _generateTransactionId() => Random().nextInt(0xFFFFFFFF);

  Uint8List _hexToBytes(String hex) {
    final bytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}

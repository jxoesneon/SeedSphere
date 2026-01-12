import 'dart:async';
import 'dart:convert';
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
  static const int _actionError = 3;

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

    RawDatagramSocket? socket;
    try {
      final address = (await InternetAddress.lookup(host)).first;
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final transactionId = _generateTransactionId();

      // 1. Connection Phase
      final connectionId = await _connect(socket, address, transactionId);
      if (connectionId == null) return {};

      // 2. Scrape Phase
      final scrapeTransactionId = _generateTransactionId();
      return await _performScrape(
        socket,
        address,
        connectionId,
        scrapeTransactionId,
        infoHashes,
      );
    } catch (e) {
      DebugLogger.error('UDP Scrape failed for $host:$port: $e');
      return {};
    } finally {
      socket?.close();
    }
  }

  Future<int?> _connect(
    RawDatagramSocket socket,
    InternetAddress address,
    int transactionId,
  ) async {
    final buffer = ByteData(16);
    buffer.setUint64(0, _protocolId, Endian.big);
    buffer.setUint32(8, _actionConnect, Endian.big);
    buffer.setUint32(12, transactionId, Endian.big);

    socket.send(buffer.buffer.asUint8List(), address, port);

    final response = await _expectResponse(socket, transactionId, 16);
    if (response == null) return null;

    final action = response.getUint32(0, Endian.big);
    if (action == _actionError) {
      final errorMsg = utf8.decode(response.buffer.asUint8List(8));
      DebugLogger.warn('UDP Connect Error from $host: $errorMsg');
      return null;
    }

    if (action != _actionConnect) return null;

    return response.getUint64(8, Endian.big);
  }

  Future<Map<String, Map<String, int>>> _performScrape(
    RawDatagramSocket socket,
    InternetAddress address,
    int connectionId,
    int transactionId,
    List<String> infoHashes,
  ) async {
    // BEP 15 scrape can handle multiple hashes (usually up to 74)
    final targets = infoHashes.take(74).toList();
    final packetSize = 16 + (targets.length * 20);
    final buffer = ByteData(packetSize);

    buffer.setUint64(0, connectionId, Endian.big);
    buffer.setUint32(8, _actionScrape, Endian.big);
    buffer.setUint32(12, transactionId, Endian.big);

    for (int i = 0; i < targets.length; i++) {
      final hashBytes = _hexToBytes(targets[i]);
      for (int j = 0; j < 20; j++) {
        buffer.setUint8(16 + (i * 20) + j, hashBytes[j]);
      }
    }

    socket.send(buffer.buffer.asUint8List(), address, port);

    final expectedSize = 8 + (targets.length * 12);
    final response = await _expectResponse(socket, transactionId, expectedSize);
    if (response == null) return {};

    final action = response.getUint32(0, Endian.big);
    if (action != _actionScrape) return {};

    final results = <String, Map<String, int>>{};
    for (int i = 0; i < targets.length; i++) {
      final offset = 8 + (i * 12);
      results[targets[i]] = {
        'seeders': response.getUint32(offset, Endian.big),
        'completed': response.getUint32(offset + 4, Endian.big),
        'leechers': response.getUint32(offset + 8, Endian.big),
      };
    }

    return results;
  }

  Future<ByteData?> _expectResponse(
    RawDatagramSocket socket,
    int expectedTransactionId,
    int minSize,
  ) async {
    final completer = Completer<ByteData?>();

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    // We can't listen multiple times to RawDatagramSocket.
    // However, we are calling _expectResponse sequentially.
    // A better approach is to use a StreamIterator or a single listener for the whole scrape() session.
    // For a quick fix, since we are only doing TWO sequential calls, we can actually just use a simple loop with socket.receive()
    // and a short sleep, or re-bind the socket for each phase.

    // Re-binding is safest given the RawDatagramSocket constraints in some environments.
    // But since we want to be efficient, let's try to drained the socket events.

    while (!completer.isCompleted) {
      final datagram = socket.receive();
      if (datagram != null && datagram.data.length >= 8) {
        final response = ByteData.sublistView(datagram.data);
        final transactionId = response.getUint32(4, Endian.big);

        if (transactionId == expectedTransactionId) {
          timer.cancel();
          completer.complete(response);
          return response;
        }
      }

      // Small delay to prevent CPU spinning if no data
      await Future.delayed(const Duration(milliseconds: 10));
    }

    timer.cancel();
    return completer.future;
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

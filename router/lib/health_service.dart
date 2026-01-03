import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for monitoring the health of P2P nodes and external trackers.
///
/// checks connectivity via HTTP/DNS/UDP and caches results to prevent abuse.
class HealthService {
  final Map<String, _HealthEntry> _cache = {};
  static const _ttl = Duration(hours: 24);
  final http.Client _client;

  /// Creates a new HealthService.
  HealthService({http.Client? client}) : _client = client ?? http.Client();

  /// Checks if a given [urlStr] is reachable and healthy.
  ///
  /// [aggressive] mode performs deeper connectivity checks (e.g. UDP handshake).
  /// Returns cached results if valid to reduce load.
  Future<bool> checkHealthy(String urlStr, {bool aggressive = false}) async {
    final now = DateTime.now();
    if (_cache.containsKey(urlStr)) {
      final entry = _cache[urlStr]!;
      if (now.difference(entry.ts) < _ttl) return entry.ok;
    }

    bool ok = false;
    try {
      final uri = Uri.parse(urlStr);

      // SSRF Protection: Resolve and check for private IPs
      if (await _isPrivateIp(uri.host)) {
        _cache[urlStr] = _HealthEntry(false, now);
        return false;
      }

      if (uri.scheme == 'udp') {
        ok = aggressive
            ? await _checkUdpAggressive(uri)
            : await _checkDns(uri.host);
      } else if (uri.scheme.startsWith('http')) {
        ok = await _checkHttp(uri);
      } else {
        ok = await _checkDns(uri.host);
      }
    } catch (_) {
      ok = false;
    }

    _cache[urlStr] = _HealthEntry(ok, now);
    return ok;
  }

  Future<bool> _checkDns(String host) async {
    try {
      final lookup = await InternetAddress.lookup(host);
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkHttp(Uri uri) async {
    try {
      final res = await _client.head(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 400) return true;
      final res2 = await _client.get(uri).timeout(const Duration(seconds: 3));
      return res2.statusCode >= 200 && res2.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkUdpAggressive(Uri uri) async {
    try {
      final host = uri.host;
      final port = uri.port;
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final txId = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF);
      final packet = ByteData(16);
      packet.setUint32(0, 0x417); // connection_id high
      packet.setUint32(4, 0x27101980); // connection_id low
      packet.setUint32(8, 0); // action (connect)
      packet.setUint32(12, txId); // transaction_id

      socket.send(packet.buffer.asUint8List(), InternetAddress(host), port);

      final completer = Completer<bool>();
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.data.length >= 16) {
            final data = ByteData.sublistView(
              Uint8List.fromList(datagram.data),
            );
            final action = data.getUint32(0);
            final rTxId = data.getUint32(4);
            if (action == 0 && rTxId == txId) {
              completer.complete(true);
            }
          }
        }
      });

      return await completer.future
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              socket.close();
              return false;
            },
          )
          .then((val) {
            socket.close();
            return val;
          });
    } catch (_) {
      return false;
    }
  }

  /// Check UDP tracker health using BitTorrent protocol handshake
  Future<bool> checkUdpTracker(
    String trackerUrl, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final uri = Uri.parse(trackerUrl);
      if (uri.scheme != 'udp') return false;

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = false;

      // BitTorrent UDP tracker protocol: Connect request
      // https://www.bittorrent.org/beps/bep_0015.html
      final buffer = BytesBuilder();

      // Connection ID (magic constant: 0x41727101980)
      buffer.add([0x00, 0x00, 0x04, 0x17, 0x27, 0x10, 0x19, 0x80]);

      // Action (0 = connect)
      buffer.add([0x00, 0x00, 0x00, 0x00]);

      // Transaction ID (random 4 bytes)
      final transactionId = List.generate(4, (_) => _random.nextInt(256));
      buffer.add(transactionId);

      // Send connect packet
      final host = await InternetAddress.lookup(uri.host);
      if (host.isEmpty) {
        socket.close();
        return false;
      }

      socket.send(buffer.toBytes(), host.first, uri.port);

      // Wait for response
      final completer = Completer<bool>();
      late StreamSubscription sub;

      sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.data.length >= 16) {
            // Valid connect response should be 16 bytes
            // action (4) + transaction_id (4) + connection_id (8)
            completer.complete(true);
          }
        }
      });

      // Timeout handler
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      final result = await completer.future;
      await sub.cancel();
      socket.close();
      return result;
    } catch (e) {
      return false;
    }
  }

  final _random = Random();

  Future<bool> _isPrivateIp(String host) async {
    try {
      final lookups = await InternetAddress.lookup(host);
      for (final addr in lookups) {
        if (addr.type == InternetAddressType.IPv4) {
          // check 127.0.0.0/8
          if (addr.rawAddress[0] == 127) {
            return true;
          }
          // check 10.0.0.0/8
          if (addr.rawAddress[0] == 10) {
            return true;
          }
          // check 172.16.0.0/12
          if (addr.rawAddress[0] == 172 &&
              addr.rawAddress[1] >= 16 &&
              addr.rawAddress[1] <= 31) {
            return true;
          }
          // check 192.168.0.0/16
          if (addr.rawAddress[0] == 192 && addr.rawAddress[1] == 168) {
            return true;
          }
          // check 169.254.0.0/16
          if (addr.rawAddress[0] == 169 && addr.rawAddress[1] == 254) {
            return true;
          }
        }
        // IPv6 Loopback
        if (addr.isLoopback) {
          return true;
        }
        // IPv6 Site Local / Link Local
        if (addr.isLinkLocal) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true; // Fail closed on DNS error
    }
  }
}

class _HealthEntry {
  final bool ok;
  final DateTime ts;
  _HealthEntry(this.ok, this.ts);
}

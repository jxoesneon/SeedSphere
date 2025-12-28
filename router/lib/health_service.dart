import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class HealthService {
  final Map<String, _HealthEntry> _cache = {};
  static const _ttl = Duration(hours: 24);

  Future<bool> checkHealthy(String urlStr, {bool aggressive = false}) async {
    final now = DateTime.now();
    if (_cache.containsKey(urlStr)) {
      final entry = _cache[urlStr]!;
      if (now.difference(entry.ts) < _ttl) return entry.ok;
    }

    bool ok = false;
    try {
      final uri = Uri.parse(urlStr);
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
      final res = await http.head(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 400) return true;
      final res2 = await http.get(uri).timeout(const Duration(seconds: 3));
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
}

class _HealthEntry {
  final bool ok;
  final DateTime ts;
  _HealthEntry(this.ok, this.ts);
}

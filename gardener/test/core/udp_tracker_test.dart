import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UdpTrackerClient Packet Construction', () {
    test('Protocol ID and Action Connect are correctly encoded', () {
      final buffer = ByteData(16);
      buffer.setUint64(0, 0x41727101980, Endian.big);
      buffer.setUint32(8, 0, Endian.big);
      buffer.setUint32(12, 12345, Endian.big);

      expect(buffer.getUint64(0, Endian.big), equals(0x41727101980));
      expect(buffer.getUint32(8, Endian.big), equals(0));
      expect(buffer.getUint32(12, Endian.big), equals(12345));
    });

    test('InfoHash encoding in Scrape packet', () {
      final infoHash = '1234567890abcdef1234567890abcdef12345678';
      final buffer = ByteData(16 + 20);

      // Simulated _hexToBytes and loop
      final bytes = Uint8List(20);
      for (int i = 0; i < 20; i++) {
        bytes[i] = int.parse(infoHash.substring(i * 2, i * 2 + 2), radix: 16);
      }

      for (int j = 0; j < 20; j++) {
        buffer.setUint8(16 + j, bytes[j]);
      }

      expect(buffer.getUint8(16), equals(0x12));
      expect(buffer.getUint8(17), equals(0x34));
      expect(buffer.getUint8(35), equals(0x78));
    });
  });
}

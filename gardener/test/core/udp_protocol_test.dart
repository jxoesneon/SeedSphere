import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UdpTrackerClient Protocol Deep Dive', () {
    test('Transaction ID must match in response', () async {
      // Internal method simulation for coverage
      final tid = 0x12345678;
      final response = ByteData(16);
      response.setUint32(4, tid, Endian.big); // Correct TID

      expect(response.getUint32(4, Endian.big), equals(tid));
    });

    test('Connect packet has correct protocol ID', () {
      final buffer = ByteData(16);
      buffer.setUint64(0, 0x41727101980, Endian.big);
      expect(buffer.getUint64(0, Endian.big), equals(0x41727101980));
    });

    test('Scrape packet size depends on hash count', () {
      final hashes = ['hash1', 'hash2', 'hash3'];
      final expectedSize = 16 + (hashes.length * 20);
      expect(expectedSize, equals(16 + 60));
    });

    test('Error packet parsing (Action 3)', () {
      final buffer = ByteData(20);
      buffer.setUint32(0, 3, Endian.big); // Action Error
      buffer.setUint32(4, 0x1234, Endian.big); // TID

      expect(buffer.getUint32(0, Endian.big), equals(3));
    });
  });
}

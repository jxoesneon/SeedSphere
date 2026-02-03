import 'package:router/boost_service.dart';
import 'package:test/test.dart';

void main() {
  group('BoostService', () {
    test('Singleton returns same instance', () {
      final s1 = BoostService();
      final s2 = BoostService();
      expect(s1, same(s2));
    });

    test('add broadcasts event and updates buffer', () async {
      final service = BoostService();
      // Record stream
      var events = <BoostEvent>[];
      final sub = service.stream.listen(events.add);

      service.add(
        'test_type',
        'Test Title',
        details: 'details',
        result: {'a': 1},
      );

      // Wait for stream microtask
      await Future.delayed(Duration.zero);

      expect(events.length, greaterThanOrEqualTo(1));
      final last = events.last;
      expect(last.type, 'test_type');
      expect(last.title, 'Test Title');

      // Check buffer
      final recent = service.getRecent();
      expect(recent.first['type'], 'test_type');
      expect(recent.first['title'], 'Test Title');

      await sub.cancel();
    });

    test('Buffer caps at 50', () {
      final service = BoostService();
      // Add 60 items
      for (var i = 0; i < 60; i++) {
        service.add('load', 'Item $i');
      }

      final recent = service.getRecent();
      expect(recent.length, lessThanOrEqualTo(50));
      // Buffer inserts at 0, so first item is 'Item 59'
      expect(recent.first['title'], 'Item 59');
    });

    test('BoostEvent serialization', () {
      final event = BoostEvent(
        type: 'A',
        title: 'B',
        details: 'C',
        metadata: {'d': 'e'},
      );
      final json = event.toJson();
      expect(json['type'], 'A');
      expect(json['title'], 'B');
      expect(json['details'], 'C');
      expect(json['d'], 'e');
      expect(json['ts'], isNotNull);
    });
  });
}

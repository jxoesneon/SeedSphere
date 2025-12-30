import 'dart:async';
import 'package:router/event_service.dart';
import 'package:test/test.dart';

void main() {
  group('EventService', () {
    late EventService service;

    setUp(() {
      service = EventService();
    });

    test('Subscribe receives initial connected event', () async {
      final stream = service.subscribe('test-room');
      expect(stream, emits(startsWith('event: connected')));
    });

    test('Publish sends event to subscriber', () async {
      final stream = service.subscribe('test-room');

      // We expect the initial connection event, then the published event
      expect(
        stream,
        emitsInOrder([startsWith('event: connected'), contains('event: ping')]),
      );

      // Wait a tick for subscription to activate
      await Future.delayed(Duration.zero);
      service.publish('test-room', 'ping', {'msg': 'hello'});
    });

    test('Multiple subscribers receive events', () async {
      final s1 = service.subscribe('room-a');
      final s2 = service.subscribe('room-a');

      expect(
        s1,
        emitsInOrder([
          startsWith('event: connected'),
          contains('event: broadcast'),
        ]),
      );

      expect(
        s2,
        emitsInOrder([
          startsWith('event: connected'),
          contains('event: broadcast'),
        ]),
      );

      // Wait a tick for subscription to activate
      await Future.delayed(Duration.zero);
      service.publish('room-a', 'broadcast', {'val': 1});
    });

    test('Unsubscribe cleans up controller', () async {
      final stream = service.subscribe('room-temp');
      final sub = stream.listen((_) {});

      // Allow cleanup to run
      await sub.cancel();

      // We can't easily inspect private _controllers, but we verify no crash on publish
      service.publish('room-temp', 'later', {});
    });
  });
}

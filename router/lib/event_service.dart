import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Service managing real-time events via Server-Sent Events (SSE).
class EventService {
  final _controllers = <String, Set<StreamController<String>>>{};

  /// Adds a subscriber to a specific room (gardenerId).
  Stream<String> subscribe(String gardenerId) {
    final controller = StreamController<String>();
    _controllers.putIfAbsent(gardenerId, () => {}).add(controller);

    controller.onCancel = () {
      _controllers[gardenerId]?.remove(controller);
      if (_controllers[gardenerId]?.isEmpty ?? false) {
        _controllers.remove(gardenerId);
      }
      controller.close();
    };

    return controller.stream;
  }

  /// Publishes an event to all subscribers in a room.
  void publish(String gardenerId, String event, Map<String, dynamic> data) {
    final payload = 'event: $event\ndata: ${jsonEncode(data)}\n\n';
    _controllers[gardenerId]?.forEach((c) => c.add(payload));
  }

  /// Helper to create a shelf Response for SSE.
  Response sseResponse(Stream<String> stream) {
    return Response.ok(
      stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive',
      },
    );
  }
}

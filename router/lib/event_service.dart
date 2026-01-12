import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:router/core/debug_config.dart';

/// Service managing real-time events via Server-Sent Events (SSE).
class EventService {
  final _controllers = <String, Set<StreamController<String>>>{};

  /// Adds a subscriber to a specific room (gardenerId).
  Stream<String> subscribe(String gardenerId) {
    if (DebugConfig.pulseGated) {
      print('EventService: New SSE subscription for gardenerId=$gardenerId');
    }
    final controller = StreamController<String>();
    _controllers.putIfAbsent(gardenerId, () => {}).add(controller);

    // Keep-alive timer to detect dead clients
    Timer? pingTimer;
    pingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!controller.isClosed) {
        controller.add(': ping\n\n');
      } else {
        pingTimer?.cancel();
      }
    });

    controller.onCancel = () {
      if (DebugConfig.pulseGated) {
        print('EventService: SSE subscription cancelled for $gardenerId');
      }
      pingTimer?.cancel();
      _controllers[gardenerId]?.remove(controller);
      if (_controllers[gardenerId]?.isEmpty ?? false) {
        _controllers.remove(gardenerId);
      }
      controller.close();
    };

    // Send initial connection event
    controller.add(
      'event: connected\ndata: {"t":${DateTime.now().millisecondsSinceEpoch}}\n\n',
    );
    if (DebugConfig.pulseGated) {
      print('EventService: Sent initial connected event to $gardenerId');
    }

    return controller.stream;
  }

  /// Publishes an event to all subscribers in a room.
  void publish(String gardenerId, String event, Map<String, dynamic> data) {
    if (_controllers.containsKey(gardenerId)) {
      final payload = 'event: $event\ndata: ${jsonEncode(data)}\n\n';
      final count = _controllers[gardenerId]!.length;
      if (DebugConfig.pulseGated || event != 'heartbeat') {
        print(
          'EventService: Broadcasting event "$event" to $count clients for $gardenerId',
        );
      }
      _controllers[gardenerId]?.forEach((c) => c.add(payload));
    } else {
      if (DebugConfig.pulseGated) {
        print('EventService: Message dropped, no subscribers for $gardenerId');
      }
    }
  }

  /// Helper to create a shelf Response for SSE.
  /// Uses buffer_output: false to disable HTTP buffering for real-time streaming.
  Response sseResponse(Stream<String> stream) {
    return Response.ok(
      stream.map(utf8.encode),
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive',
        'X-Accel-Buffering': 'no', // Disable nginx proxy buffering
      },
      context: {
        'shelf.io.buffer_output': false, // Disable dart:io HTTP buffering
      },
    );
  }
}

import 'dart:async';

/// Represents a system activity event ("Boost").
class BoostEvent {
  /// The type of event (e.g., 'stream_found').
  final String type;

  /// Human readable title for the event.
  final String title;

  /// Extra descriptive information.
  final String details;

  /// When the event occurred (ms since epoch).
  final int timestamp;

  /// Additional structured metadata.
  final Map<String, dynamic> metadata;

  /// Creates a new BoostEvent.
  BoostEvent({
    required this.type,
    required this.title,
    this.details = '',
    this.metadata = const {},
  }) : timestamp = DateTime.now().millisecondsSinceEpoch;

  /// Converts the event to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'details': details,
    'ts': timestamp,
    ...metadata,
  };
}

/// Manages a ring buffer of recent events and broadcasts them to subscribers (SSE).
class BoostService {
  static const int _capacity = 50;
  final List<BoostEvent> _buffer = [];
  final _controller = StreamController<BoostEvent>.broadcast();

  // Singleton instance
  static final BoostService _instance = BoostService._internal();

  /// Returns the singleton instance of BoostService.
  factory BoostService() => _instance;

  BoostService._internal();

  /// Adds a new event to the system.
  void add(
    String type,
    String title, {
    String details = '',
    Map<String, dynamic> result = const {},
  }) {
    final event = BoostEvent(
      type: type,
      title: title,
      details: details,
      metadata: result,
    );

    _buffer.insert(0, event);
    if (_buffer.length > _capacity) {
      _buffer.removeLast();
    }

    _controller.add(event);
  }

  /// Returns the most recent events.
  List<Map<String, dynamic>> getRecent() {
    return _buffer.map((e) => e.toJson()).toList();
  }

  /// Subscribes to the live event stream.
  Stream<BoostEvent> get stream => _controller.stream;

  /// Closes the event stream.
  void dispose() {
    _controller.close();
  }
}

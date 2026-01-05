import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Represents a single log entry in the system.
class LogEntry {
  final DateTime timestamp;
  final String message;
  final int level;
  final String? category;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.category,
    this.error,
    this.stackTrace,
  });

  String get levelLabel {
    if (level >= 1200) return 'SECURITY';
    if (level >= 1000) return 'ERROR';
    if (level >= 900) return 'WARN';
    if (level >= 800) return 'INFO';
    return 'DEBUG';
  }
}

/// A structured logging utility for SeedSphere Gardener.
///
/// Integrated with `dart:developer` to ensure logs are visible in
/// Antigravity and other DTD-compatible tooling.
///
/// Now supports in-memory persistence for real-time UI debugging.
class DebugLogger {
  static const String _name = 'Gardener';
  static const int _maxLogs = 1000;

  static final List<LogEntry> _logs = [];
  static final ValueNotifier<List<LogEntry>> logsNotifier =
      ValueNotifier<List<LogEntry>>([]);

  /// Returns a copy of the current logs.
  static List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Log an informational message.
  static void info(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: 800,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a warning message.
  static void warn(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: 900,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message.
  static void error(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: 1000,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a security-related message.
  static void security(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      '[SECURITY] $message',
      level: 1200,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a verbose debug message (only in debug mode).
  static void debug(
    String message, {
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _log(
        message,
        level: 500,
        category: category,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clears all stored logs.
  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }

  static void _log(
    String message, {
    required int level,
    String? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();

    // Create entry
    final entry = LogEntry(
      timestamp: now,
      message: message,
      level: level,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to buffer
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Notify listeners
    logsNotifier.value = List.from(_logs);

    // Platform logging
    developer.log(
      message,
      name: _name,
      level: level,
      error: error,
      stackTrace: stackTrace,
      time: now,
    );

    // Also print to console for environments without DTD stream support
    if (kDebugMode) {
      debugPrint('[$_name] $message');
      if (error != null) debugPrint('Error: $error');
    }
  }
}

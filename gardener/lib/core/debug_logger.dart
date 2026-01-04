import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// A structured logging utility for SeedSphere Gardener.
///
/// Integrated with `dart:developer` to ensure logs are visible in
/// Antigravity and other DTD-compatible tooling.
class DebugLogger {
  static const String _name = 'Gardener';

  /// Log an informational message.
  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: 800, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message.
  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: 900, error: error, stackTrace: stackTrace);
  }

  /// Log an error message.
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: 1000, error: error, stackTrace: stackTrace);
  }

  /// Log a security-related message.
  static void security(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      '[SECURITY] $message',
      level: 1200,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a verbose debug message (only in debug mode).
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log(message, level: 500, error: error, stackTrace: stackTrace);
    }
  }

  static void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: _name,
      level: level,
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );

    // Also print to console for environments without DTD stream support
    if (kDebugMode) {
      debugPrint('[$_name] $message');
      if (error != null) debugPrint('Error: $error');
    }
  }
}

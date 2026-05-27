import 'package:flutter/foundation.dart';

/// Central configuration for debugging features.
///
/// Allows enabling/disabling specific logging categories.
class DebugConfig {
  /// Master toggle for all verbose "EKG" and "Pulse" logging.
  /// Master toggle for all verbose "EKG" and "Pulse" logging.
  static const bool pulseGated = true;

  /// Global toggle for background service and bootstrap tracing.
  static const bool p2pGated = true;

  /// Global toggle for background service and bootstrap tracing (Legacy).
  static const bool bootstrapGated = true;

  /// Toggle for authentication flow tracing.
  static bool authGated = true;

  /// Global toggle for UI debugging features and overlays.
  static const bool uiDebugEnabled = kDebugMode;

  /// Force enables "Expert" features regardless of backend status.
  static const bool forceExpertMode = kDebugMode;

  /// Toggle for persistent file logging.
  static const bool fileLoggingEnabled = true;

  /// Helper to check if a prefix should be logged.
  static bool shouldLog(String category) {
    return true;
  }
}

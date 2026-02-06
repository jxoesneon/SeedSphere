import 'package:flutter/foundation.dart';

/// Central configuration for debugging features.
///
/// Allows enabling/disabling specific logging categories.
class DebugConfig {
  /// Master toggle for all verbose "EKG" and "Pulse" logging.
  /// Master toggle for all verbose "EKG" and "Pulse" logging.
  static const bool pulseGated = kDebugMode;

  /// Global toggle for background service and bootstrap tracing.
  static const bool p2pGated = kDebugMode;

  /// Global toggle for background service and bootstrap tracing (Legacy).
  static const bool bootstrapGated = kDebugMode;

  /// Toggle for authentication flow tracing.
  static bool authGated = kDebugMode;

  /// Global toggle for UI debugging features and overlays.
  static const bool uiDebugEnabled = kDebugMode;

  /// Force enables "Expert" features regardless of backend status.
  static const bool forceExpertMode = kDebugMode;

  /// Toggle for persistent file logging.
  static const bool fileLoggingEnabled = false;

  /// Helper to check if a prefix should be logged.
  static bool shouldLog(String category) {
    if (!kDebugMode) return false;
    if (category == 'EKG' || category == 'PULSE') return pulseGated;
    if (category == 'BOOTSTRAP') return bootstrapGated;
    if (category == 'AUTH') return authGated;
    return true;
  }
}

/// Central configuration for debugging features in the router.
///
/// Allows enabling/disabling specific logging categories.
class DebugConfig {
  /// Master toggle for all verbose "EKG", "Pulse", and "Heartbeat" logging.
  /// Set to false to silence high-frequency logs.
  static const bool pulseGated = false;

  /// Global toggle for background service and bootstrap tracing.
  static const bool p2pGated = true;

  /// Helper to check if a category should be logged.
  static bool shouldLog(String category) {
    if (category == 'EKG' || category == 'PULSE' || category == 'HEARTBEAT') {
      return pulseGated;
    }
    if (category == 'P2P') {
      return p2pGated;
    }
    return true;
  }
}

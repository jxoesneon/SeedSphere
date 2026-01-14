/// Network connectivity status for the swarm uplink.
enum NetworkStatus {
  /// Optimal connectivity with good peer count
  optimal,

  /// Limited connectivity or degraded performance
  degraded,

  /// No network connection
  offline,

  /// Checking connection status
  checking,
}

import 'package:router/event_service.dart';
import 'package:router/db_service.dart';

/// Manages active status and heartbeats of Gardeners.
class StatusService {
  final DbService _db;

  /// Service for publishing real-time events.
  final EventService _events;

  /// Active gardeners mapped by ID to last heartbeat timestamp.
  final Map<String, DateTime> _activeGardeners = {};

  /// Creates a [StatusService].
  StatusService(this._db, this._events);

  /// Registers a heartbeat from a gardener.
  void recordHeartbeat(String gardenerId) {
    _activeGardeners[gardenerId] = DateTime.now();

    // Cleanup stale gardeners (inactive > 2 minutes)
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    _activeGardeners.removeWhere((_, lastSeen) => lastSeen.isBefore(cutoff));

    _db.touchGardener(gardenerId);

    _events.publish(gardenerId, 'heartbeat', {
      't': DateTime.now().millisecondsSinceEpoch,
      'active': _activeGardeners.length,
    });
  }

  /// Returns the number of currently active gardeners.
  int get activeCount => _activeGardeners.length;

  /// Returns true if a gardener is considered active.
  bool isActive(String gardenerId) {
    final lastSeen = _activeGardeners[gardenerId];
    if (lastSeen == null) return false;

    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    if (lastSeen.isBefore(cutoff)) {
      _activeGardeners.remove(gardenerId);
      return false;
    }
    return true;
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Manages persistent peer and user identities for P2P networking.
///
/// Generates and persists UUIDs for peer identification in the swarm network.
/// Supports identity rotation for privacy and security.
///
/// Example:
/// ```dart
/// final identity = IdentityManager();
/// final peerId = await identity.getPeerId(); // e.g., "550e8400-e29b-41d4-a716-446655440000"
/// final gardenerId = await identity.getGardenerId(); // e.g., "gardener-550e8400"
/// ```
class IdentityManager {
  final FlutterSecureStorage _storage;
  static const _peerIdKey = 'ss_peer_id';
  static const _gardenerIdKey = 'ss_gardener_id';

  /// Creates a new [IdentityManager] instance.
  ///
  /// [storage] - Optional secure storage for testing. Defaults to [FlutterSecureStorage].
  IdentityManager({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Retrieves or generates a unique peer ID for P2P networking.
  ///
  /// Generates a new UUIDv4 if no peer ID exists, otherwise returns
  /// the existing ID. The peer ID persists across app restarts.
  ///
  /// Returns a UUIDv4 string uniquely identifying this peer in the swarm.
  Future<String> getPeerId() async {
    String? id = await _storage.read(key: _peerIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _peerIdKey, value: id);
    }
    return id;
  }

  /// Retrieves or generates a human-readable gardener/user ID.
  ///
  /// Generates a friendlier ID using the "gardener-" prefix followed by
  /// the first 8 characters of a UUIDv4. This is used for UI display.
  ///
  /// Returns a gardener ID string (e.g., "gardener-a3f5c8b2").
  Future<String> getGardenerId() async {
    String? id = await _storage.read(key: _gardenerIdKey);
    if (id == null) {
      id = 'gardener-${const Uuid().v4().substring(0, 8)}';
      await _storage.write(key: _gardenerIdKey, value: id);
    }
    return id;
  }

  /// Rotates (resets) both peer and gardener identities.
  ///
  /// Deletes existing IDs from secure storage. New IDs will be generated
  /// on the next call to [getPeerId] or [getGardenerId].
  ///
  /// Use this for privacy (changing identity in the swarm) or when
  /// troubleshooting P2P issues.
  Future<void> rotateIdentity() async {
    await _storage.delete(key: _peerIdKey);
    await _storage.delete(key: _gardenerIdKey);
  }
}

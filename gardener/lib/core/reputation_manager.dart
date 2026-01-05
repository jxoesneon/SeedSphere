import 'package:flutter/foundation.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';

/// Tracks peer reputation scores for spam and abuse prevention.
///
/// Maintains a simple scoring system where peers start at 0 and can gain
/// or lose points based on behavior. Peers falling below the threshold
/// are automatically blacklisted.
///
/// **Scoring guidelines:**
/// - Good behavior (sharing valid streams): +1 to +5
/// - Invalid data or timeouts: -5 to -10
/// - Spam or malicious activity: -20 to -50
///
/// Example:
/// ```dart
/// final reputation = ReputationManager();
///
/// // Peer shared good stream
/// reputation.adjustScore(peerId, +5);
///
/// // Peer sent spam
/// reputation.adjustScore(peerId, -30);
///
/// if (reputation.isBlacklisted(peerId)) {
///   // Ignore all future messages from this peer
/// }
/// ```
class ReputationManager {
  final P2PManager _p2p;
  final Map<String, int> _peerScores = {};

  ReputationManager(this._p2p);

  /// Reputation threshold below which peers are blacklisted.
  static const int _threshold = -50;

  /// Adjusts a peer's reputation score.
  ///
  /// [peerId] - The unique peer identifier.
  /// [delta] - The score change (positive for good behavior, negative for bad).
  ///
  /// If the peer's score falls below [_threshold], they are automatically
  /// blacklisted and the P2P network is notified to ignore them.
  void adjustScore(String peerId, int delta) {
    _peerScores[peerId] = (_peerScores[peerId] ?? 0) + delta;
    if (_peerScores[peerId]! < _threshold) {
      _blacklistPeer(peerId);
    }
  }

  /// Checks if a peer is blacklisted due to low reputation.
  ///
  /// [peerId] - The peer identifier to check.
  ///
  /// Returns `true` if the peer's score is below the blacklist threshold.
  bool isBlacklisted(String peerId) {
    return (_peerScores[peerId] ?? 0) < _threshold;
  }

  /// Blacklists a peer with critically low reputation.
  ///
  /// [peerId] - The peer to blacklist.
  ///
  /// Logs the blacklisting event. In a full implementation, this would
  /// notify the P2P isolate to drop all connections from this peer.
  void _blacklistPeer(String peerId) {
    _p2p.sendCommand(
      P2PCommand(
        type: P2PCommandType.blacklist,
        imdbId: 'reputation:blacklist',
        data: {'peerId': peerId},
      ),
    );
    debugPrint('SECURITY: Peer $peerId blacklisted due to low reputation');
  }

  /// Retrieves the current reputation score for a peer.
  ///
  /// [peerId] - The peer identifier.
  ///
  /// Returns the peer's score, or 0 if the peer is unknown (neutral reputation).
  int getScore(String peerId) => _peerScores[peerId] ?? 0;
}

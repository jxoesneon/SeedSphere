import 'dart:io';
import 'package:dart_ipfs/dart_ipfs.dart';

/// Manages the libp2p bootstrap node lifecycle on the Router.
class P2PNode {
  IPFSNode? _node;
  bool _initialized = false;

  /// Starts the IPFS node with bootstrap configuration.
  Future<void> start() async {
    if (_initialized) return;

    try {
      print('P2P: Initializing SeedSphere Bootstrap Node...');

      // 0. Cleanup Stale Locks (State Management)
      // Fixes "lock failed" error after crashes
      final lockFile = File('./ipfs_data/blocks.lock');
      if (lockFile.existsSync()) {
        try {
          lockFile.deleteSync();
          print('P2P: 🧹 Removed stale DB lock file.');
        } catch (e) {
          print('P2P: ⚠️ Could not remove lock file (active process?): $e');
          // If we can't delete it, it might be truly locked, so we proceed and let it fail naturally
        }
      }

      // 1. Configure Private Swarm if Key Provided
      final swarmKey = Platform.environment['P2P_SWARM_KEY'];
      if (swarmKey != null) {
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        final repoPath = Platform.environment['IPFS_PATH'] ?? '$home/.ipfs';

        final dir = Directory(repoPath);
        if (!dir.existsSync()) dir.createSync(recursive: true);

        final keyFile = File('${dir.path}/swarm.key');
        // swarm.key format: /key/swarm/psk/1.0.0/\n/base16/\n<key>
        if (!keyFile.existsSync() || keyFile.readAsStringSync() != swarmKey) {
          keyFile.writeAsStringSync(
            '/key/swarm/psk/1.0.0/\n/base16/\n$swarmKey',
          );
          print('P2P: Private Swarm Key Configured');
        }
      }

      _node = await IPFSNode.create(
        IPFSConfig(
          offline: false,
          network: const NetworkConfig(
            listenAddresses: ['/ip4/0.0.0.0/udp/2022', '/ip6/::/udp/2022'],
            // Use default public bootstrap nodes (Protocol Labs, etc.)
          ),
        ),
      );

      await _node!.start();
      _initialized = true;

      print('P2P: Bootstrap Node Active');
      print('P2P: PeerID: ${_node!.peerId}');
      print('P2P: Listening on: ${_node!.addresses}');
    } catch (e) {
      print('P2P: Failed to start bootstrap node: $e');
      rethrow;
    }
  }

  /// Stops the IPFS node.
  Future<void> stop() async {
    if (!_initialized) return;
    await _node?.stop();
    _initialized = false;
  }

  /// Returns the PeerID of the node.
  String? get peerId => _node?.peerId.toString();

  /// Returns the multiaddresses of the node.
  List<String> get addresses =>
      _node?.addresses.map((m) => m.toString()).toList() ?? [];
}

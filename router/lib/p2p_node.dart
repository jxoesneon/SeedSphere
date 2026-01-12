import 'dart:io';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:router/core/debug_config.dart';

/// Factory for creating IPFS nodes (allows mocking).
typedef NodeFactory = Future<IPFSNode> Function(IPFSConfig config);

/// Manages the libp2p bootstrap node lifecycle on the Router.
class P2PNode {
  IPFSNode? _node;
  bool _initialized = false;
  final NodeFactory _nodeFactory;

  /// Creates a new P2PNode instance.
  P2PNode({NodeFactory? nodeFactory})
    : _nodeFactory = nodeFactory ?? IPFSNode.create;

  /// Starts the IPFS node with bootstrap configuration.
  Future<void> start() async {
    if (_initialized) return;

    try {
      print('P2P: Initializing SeedSphere Bootstrap Node...');

      // 0. Cleanup Stale Locks (State Management)
      // Fixes "lock failed" error after crashes
      // 0. Cleanup Stale Locks (State Management)
      // Fixes "lock failed" error after crashes (blocks.lock, pins.lock, etc.)
      // 0.5 Permission & Path Auditing
      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      print('DEBUG: User Home: $homeDir');
      print('DEBUG: Current PID: $pid');
      print('DEBUG: Current Directory: ${Directory.current.path}');

      final dataDir = Directory('./ipfs_data');
      if (dataDir.existsSync()) {
        try {
          final lockFiles = dataDir.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.lock'),
          );

          for (final file in lockFiles) {
            file.deleteSync();
            print('P2P: 🧹 Removed stale lock file: ${file.path}');
          }
        } catch (e) {
          print('P2P: ⚠️ Could not ensure lock cleanup: $e');
        }
      }

      // 1. Configure Private Swarm if Key Provided
      final swarmKey =
          Platform.environment['P2P_SWARM_KEY'] ??
          'seedsphere-dev-swarm-2025'; // Match Gardener's default for dev

      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      final repoPath =
          Platform.environment['IPFS_PATH'] ??
          (Platform.isWindows ? '$home\\.ipfs' : '$home/.ipfs');
      print('DEBUG: Resolved IPFS_PATH: $repoPath');

      final dir = Directory(repoPath);
      if (!dir.existsSync()) {
        print('DEBUG: Creating repo directory...');
        dir.createSync(recursive: true);
      }

      try {
        final testFile = File('${dir.path}/perm_test');
        testFile.writeAsStringSync('write_test');
        testFile.deleteSync();
        print('DEBUG: ✅ Write permission confirmed for $repoPath');
      } catch (e) {
        print('DEBUG: ❌ Write permission FAILED for $repoPath: $e');
      }

      final keyFile = File('${dir.path}/swarm.key');
      // swarm.key format: /key/swarm/psk/1.0.0/\n/base16/\n<key>
      if (!keyFile.existsSync() || keyFile.readAsStringSync() != swarmKey) {
        keyFile.writeAsStringSync('/key/swarm/psk/1.0.0/\n/base16/\n$swarmKey');
        print('P2P: Private Swarm Key Configured');
      }

      // 1. Configure Private Swarm if Key Provided
      print('DEBUG: Loading P2PNode with PORT 4005 CONFIG');
      _node = await _nodeFactory(
        IPFSConfig(
          offline: false,
          // --- LIBP2P BRIDGE ---
          enableLibp2pBridge:
              true, // Enable TCP transport for Gardener compatibility
          libp2pListenAddress: '/ip4/0.0.0.0/tcp/4005', // Listen on TCP 4005
          // --------------------
          network: NetworkConfig(
            listenAddresses: [
              '/ip4/0.0.0.0/udp/4005',
              '/ip4/0.0.0.0/tcp/4005', // TCP for dart_libp2p bridge
            ],
            // Disable external bootstraps for now to avoid PeerId length errors
            // We will rely on mDNS and dynamic discovery for local testing.
            bootstrapPeers: [],
          ),
        ),
      );

      await _node!.start();
      _initialized = true;

      if (DebugConfig.p2pGated) {
        print('P2P: Bootstrap Node Active');
        print('P2P: PeerID: ${_node!.peerId}');
        print('P2P: Listening on: ${_node!.addresses}');
      }
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

import 'dart:async';
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

      _node = await IPFSNode.create(
        IPFSConfig(
          offline: false,
          network: const NetworkConfig(
            listenAddresses: [
              '/ip4/0.0.0.0/tcp/4001',
              '/ip4/0.0.0.0/udp/4001/quic',
            ],
            // As a bootstrap node, we don't necessarily need bootstrap peers,
            // but we can include the IPFS defaults for connectivity.
            bootstrapPeers: [
              '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnoo2uRhyMvRcrqQLmb7td3AddvXYZdqHqcSWtd4p5hc',
              '/dnsaddr/bootstrap.libp2p.io/p2p/QmZa1s3K39YSUEB8iHUC8mcGEnmsVvYkjW4pToXyT9QByW',
            ],
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

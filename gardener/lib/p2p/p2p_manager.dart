import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';

/// Provider for the [P2PManager] instance.
///
/// Automatically handles disposal by stopping the P2P node when the provider
/// is no longer used.
final p2pManagerProvider = Provider<P2PManager>((ref) {
  final manager = P2PManager();
  ref.onDispose(() => manager.stop());
  return manager;
});

/// Orchestrates the P2P networking layer using a background isolate.
class P2PManager {
  /// The background isolate running the IPFS node.
  Isolate? _p2pIsolate;

  /// Port used to send commands to the background isolate.
  @visibleForTesting
  SendPort? toIsolatePort;

  /// Port used to receive messages from the background isolate.
  final ReceivePort _fromIsolatePort = ReceivePort();

  final FlutterSecureStorage _storage;
  final SecurityManager _security;
  bool _isInitialized = false;
  Timer? _heartbeatTimer;
  String? _gardenerId;

  P2PManager({FlutterSecureStorage? storage, SecurityManager? security})
      : _storage = storage ?? const FlutterSecureStorage(),
        _security = security ?? SecurityManager();

  /// Whether the P2P isolate is started and the handshake is complete.
  bool get isInitialized => _isInitialized;

  /// The unique identifier for this Gardener node.
  String? get gardenerId => _gardenerId;

  /// Starts the background P2P isolate and initializes the IPFS node.
  ///
  /// Spawns a new [Isolate] with [_p2pIsolateEntryPoint] and establishes
  /// a bidirectional communication channel via [SendPort] and [ReceivePort].
  ///
  /// Throws if isolate spawning fails.
  Future<void> start() async {
    if (_isInitialized) return;

    // Load or generate Gardener ID
    final savedId = await _storage.read(key: 'ss_gardener_id');
    if (savedId == null) {
      _gardenerId = const Uuid().v4();
      await _storage.write(key: 'ss_gardener_id', value: _gardenerId!);
    } else {
      _gardenerId = savedId;
    }

    _p2pIsolate = await Isolate.spawn(
      _p2pIsolateEntryPoint,
      _fromIsolatePort.sendPort,
      debugName: 'SS_P2P_Isolate',
    );

    _fromIsolatePort.listen((message) {
      if (message is SendPort) {
        toIsolatePort = message;
        _isInitialized = true;
        debugPrint('P2P: Isolate handshake complete');
        _startHeartbeatTimer();
      } else if (message is String) {
        debugPrint('P2P Isolate Msg: $message');
      }
    });
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _sendHeartbeat();
    });
    // Send immediate first heartbeat
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    if (_gardenerId == null) return;

    final secret = await _security.getSharedSecret();
    if (secret == null) {
      debugPrint('P2P: Heartbeat skipped (no shared secret)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = const Uuid().v4();
    final body = jsonEncode({'status': 'active', 't': ts});

    // In SeedSphere 2.0, the seedlingId during heartbeat is often fixed or derived
    // for self-presence. For parity linking, we use the gardenerId as seedling part
    // if it's a "solo" announcement, or the real seedlingId if known.
    const seedlingId = 'self';

    final sig = await _security.generateHmacSignature(
      method: 'POST',
      path: '/api/rooms/$_gardenerId/heartbeat',
      query: '',
      body: body,
      timestamp: ts,
      nonce: nonce,
    );

    if (sig == null) return;

    try {
      const baseUrl = 'https://seedsphere-router.fly.dev';
      await http.post(
        Uri.parse('$baseUrl/api/rooms/$_gardenerId/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'X-SeedSphere-Sig': sig,
          'X-SeedSphere-Ts': ts,
          'X-SeedSphere-Nonce': nonce,
          'X-SeedSphere-G': _gardenerId!,
          'X-SeedSphere-Id': seedlingId,
        },
        body: body,
      );
      debugPrint('P2P: Heartbeat sent to Router');
    } catch (e) {
      debugPrint('P2P: Heartbeat failed: $e');
    }
  }

  /// Sends a raw [P2PCommand] to the background isolate.
  ///
  /// If the isolate is not yet ready, the command is dropped and an error
  /// is logged to the console.
  void sendCommand(P2PCommand command) {
    if (toIsolatePort != null) {
      toIsolatePort!.send(command.toJson());
    } else {
      debugPrint('P2P Error: Isolate not ready');
    }
  }

  /// Searches the swarm for metadata associated with an IMDB ID.
  ///
  /// Triggers a Gossipsub subscription and a DHT provider lookup.
  void search(String imdbId) =>
      sendCommand(P2PCommand(type: P2PCommandType.search, imdbId: imdbId));

  /// Publishes local availability of metadata for an IMDB ID.
  ///
  /// Registers the local peer as a provider in the DHT for the given ID.
  void publish(String imdbId) =>
      sendCommand(P2PCommand(type: P2PCommandType.publish, imdbId: imdbId));

  /// Attempts to retrieve a block of data via CID.
  ///
  /// Uses Bitswap to fetch raw data blocks from the network.
  void getContent(String cid) =>
      sendCommand(P2PCommand(type: P2PCommandType.get, imdbId: cid));

  /// Stops the background isolate and releases network resources.
  ///
  /// Kills the P2P isolate immediately and resets initialization state.
  void stop() {
    _p2pIsolate?.kill(priority: Isolate.immediate);
    _isInitialized = false;
  }

  /// Entry point for the P2P background isolate.
  ///
  /// [fromMainPort] - SendPort to communicate back with the main thread.
  ///
  /// This method is responsible for:
  /// 1. Setting up a [ReceivePort] to receive commands from the main thread.
  /// 2. Initializing the [IPFSNode] with a Federated configuration.
  /// 3. Listening for and dispatching incoming [P2PCommand]s.
  static void _p2pIsolateEntryPoint(SendPort fromMainPort) async {
    // coverage:ignore-start
    final ReceivePort toIsolatePort = ReceivePort();
    fromMainPort.send(toIsolatePort.sendPort);

    try {
      fromMainPort.send('P2P: Initializing IPFS Node...');

      // 1. Configure Private Swarm
      const swarmKey =
          '/key/swarm/psk/1.0.0/\n/base16/\n4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a';

      // Use default IPFS path logic (replicates Router behavior)
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      final repoPath =
          Platform.environment['IPFS_PATH'] ?? '${home ?? "."}/.ipfs';

      final repoDir = Directory(repoPath);
      if (!repoDir.existsSync()) repoDir.createSync(recursive: true);

      final keyFile = File('${repoDir.path}/swarm.key');
      await keyFile.writeAsString(swarmKey);

      final IPFSNode node = await IPFSNode.create(
        IPFSConfig(
          offline: false,
          network: const NetworkConfig(
            listenAddresses: [
              '/ip4/0.0.0.0/tcp/4001',
              '/ip4/0.0.0.0/udp/4001/quic'
            ],
            // PRIVACY FIX: Only connect to trusted SeedSphere routers.
            bootstrapPeers: [
              '/dnsaddr/seedsphere-router.fly.dev/tcp/4001',
            ],
          ),
        ),
      );

      await node.start();
      fromMainPort.send('P2P: Federated Node Active | PeerID: ${node.peerId}');

      toIsolatePort.listen((message) async {
        await handleWorkerMessage(message, node, fromMainPort);
      });
    } catch (e) {
      fromMainPort.send('P2P Error: ${e.toString()}');
    }
    // coverage:ignore-end
  }

  /// Processes commands received within the worker isolate.
  ///
  /// Dispatches commands to the [IPFSNode] based on [P2PCommandType].
  /// Reports results back to the main thread via [fromMainPort].
  @visibleForTesting
  static Future<void> handleWorkerMessage(
      dynamic message, dynamic node, SendPort fromMainPort) async {
    if (message is Map<String, dynamic>) {
      final command = P2PCommand.fromJson(message);

      switch (command.type) {
        case P2PCommandType.search:
          fromMainPort.send('P2P: Searching for ${command.imdbId}...');
          // 1. Subscribe to IMDB topic (Gossipsub)
          final topic = P2PProtocol.getTopic(command.imdbId);
          await node.subscribe(topic);

          // 2. DHT Find Providers
          final dhtKey = P2PProtocol.getDhtKey(command.imdbId);
          final providers = await node.dhtClient.findProviders(dhtKey);
          fromMainPort.send('P2P: Found ${providers.length} swarm providers');
          break;

        case P2PCommandType.publish:
          fromMainPort.send('P2P: Seeding metadata for ${command.imdbId}');
          final dhtKey = P2PProtocol.getDhtKey(command.imdbId);
          await node.dhtClient.addProvider(dhtKey, node.peerId);
          break;

        case P2PCommandType.boost:
          final topic = P2PProtocol.getTopic(command.imdbId);
          final payload = jsonEncode(command.data);
          await node.publish(topic, payload);
          break;

        case P2PCommandType.get:
          fromMainPort
              .send('P2P: Fetching block ${command.imdbId} via Bitswap...');
          try {
            final blockData = await node.get(command.imdbId);
            if (blockData != null) {
              fromMainPort
                  .send('P2P: Recieved block data: ${blockData.length} bytes');
            } else {
              fromMainPort.send('P2P: Block not found');
            }
          } catch (e) {
            fromMainPort.send('P2P Bitswap Error: ${e.toString()}');
          }
          break;

        case P2PCommandType.status:
          final peers = await node.connectedPeers;
          fromMainPort.send('P2P Status: ${peers.length} active peers');
          break;
      }
    }
  }
}

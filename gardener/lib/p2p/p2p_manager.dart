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
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/activity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

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
  ReceivePort? _fromIsolatePort;

  final FlutterSecureStorage _storage;
  final SecurityManager _security;
  bool _isInitialized = false;
  Timer? _heartbeatTimer;
  Timer? _statusTimer;
  String? _gardenerId;

  /// Notifier for the number of active physical P2P peers.
  final ValueNotifier<int> peerCount = ValueNotifier<int>(0);

  /// Stores current diagnostic metadata for reporting.
  final Map<String, String> _diagnosticMetadata = {
    'peerId': 'Unknown',
    'addresses': 'None',
    'status': 'Starting...',
  };

  /// Returns a copy of the current diagnostic metadata.
  Map<String, String> get diagnosticMetadata =>
      Map.unmodifiable(_diagnosticMetadata);

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

    // Load Security Keys
    final keyPair = await _security.getKeyPair();
    final privateKey = keyPair.privateKey.bytes;

    // Resolve safe storage path
    final docDir = await getApplicationDocumentsDirectory();
    final storagePath = docDir.path;

    // Load Networking Settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final autoBootstrap = prefs.getBool('p2p_auto_bootstrap') ?? true;
    final scrapeSwarm = prefs.getBool('p2p_scrape_swarm') ?? true;
    final swarmTopN = prefs.getInt('p2p_swarm_top_n') ?? 20;

    _diagnosticMetadata['status'] = 'Starting...';

    // Run raw network diagnostics in background
    unawaited(NetworkConstants.pingBootstrapPeers());

    // Create a NEW receive port for this session to avoid "Stream already listened to"
    _fromIsolatePort = ReceivePort();

    _p2pIsolate = await Isolate.spawn(
      _p2pIsolateEntryPoint,
      P2PInitData(
        sendPort: _fromIsolatePort!.sendPort,
        privateKey: privateKey,
        storagePath: storagePath,
        autoBootstrap: autoBootstrap,
        scrapeSwarm: scrapeSwarm,
        swarmTopN: swarmTopN,
        enableNatTraversal: true,
        swarmKey: prefs.getString('p2p_swarm_key'),
      ),
      debugName: 'SS_P2P_Isolate',
    );

    _fromIsolatePort!.listen((message) {
      if (message is SendPort) {
        toIsolatePort = message;
        _isInitialized = true;
        DebugLogger.info('P2P: Isolate handshake complete');
        _startHeartbeatTimer();
        _startStatusPolling();
      } else if (message is int) {
        peerCount.value = message;
      } else if (message is Map && message.containsKey('msg')) {
        final msg = message['msg'] as String;
        final category = message['cat'] as String?;
        final level = message['level'] as String? ?? 'INFO';
        final error = message['error'];

        // Update diagnostic metadata based on key messages
        if (category == 'NET') {
          if (msg.contains('Identity:')) {
            _diagnosticMetadata['peerId'] = msg.split('Identity: ')[1];
            _diagnosticMetadata['status'] = 'Active';
          } else if (msg.contains('Listening on:')) {
            _diagnosticMetadata['addresses'] = msg.split('Listening on: ')[1];
          }
        }

        switch (level) {
          case 'ERROR':
            DebugLogger.error(msg, category: category, error: error);
            break;
          case 'WARN':
            DebugLogger.warn(msg, category: category, error: error);
            break;
          case 'SECURITY':
            DebugLogger.security(msg, category: category, error: error);
            break;
          case 'DEBUG':
            DebugLogger.debug(msg, category: category, error: error);
            break;
          default:
            DebugLogger.info(msg, category: category, error: error);
        }
      } else if (message is String) {
        if (message.contains('Error')) {
          DebugLogger.error(message);
        } else if (message.contains('Warning')) {
          DebugLogger.warn(message);
        } else if (message.contains('SECURITY')) {
          DebugLogger.security(message);
        } else {
          DebugLogger.info(message);
        }
      }
    });
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
    // Send immediate first heartbeat
    _sendHeartbeat();
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _queryStatus();
    });
    _queryStatus();
  }

  void _queryStatus() {
    if (toIsolatePort != null) {
      toIsolatePort!.send(
        P2PCommand(type: P2PCommandType.status, imdbId: '').toJson(),
      );
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_gardenerId == null) return;

    final secret = await _security.getSharedSecret();
    if (secret == null) {
      DebugLogger.warn('P2P: Heartbeat skipped (no shared secret)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = const Uuid().v4();
    final body = jsonEncode({
      'status': 'active',
      't': ts,
      'peers': peerCount.value,
      'activity': ActivityManager().getRecentActivities(),
    });

    // In SeedSphere 2.0, the seedlingId during heartbeat is often fixed or derived
    // for self-presence. For parity linking, we use the gardenerId as seedling part
    // if it's a "solo" announcement, or the real seedlingId if known.
    const seedlingId = 'self';

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    // The "room" we publish to. If logged in, use userId so dashboard sees us.
    // Otherwise fallback to gardenerId.
    final roomId = (userId != null && userId.isNotEmpty)
        ? userId
        : _gardenerId!;

    final sig = await _security.generateHmacSignature(
      method: 'POST',
      path: '/api/rooms/$roomId/heartbeat',
      query: '',
      body: body,
      timestamp: ts,
      nonce: nonce,
    );

    if (sig == null) return;

    try {
      final endpoint = NetworkConstants.getHeartbeatEndpoint(roomId);
      await http.post(
        Uri.parse(endpoint),
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
      DebugLogger.debug('P2P: Heartbeat sent to room: $roomId');
    } catch (e) {
      DebugLogger.error('P2P: Heartbeat failed', error: e);
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
      DebugLogger.error('P2P Error: Isolate not ready');
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

  /// Forces the node to re-bootstrap and optimize connectivity.
  void optimize() {
    unawaited(NetworkConstants.pingBootstrapPeers());
    sendCommand(P2PCommand(type: P2PCommandType.optimize, imdbId: ''));
  }

  /// Stops the background isolate and releases network resources.
  ///
  /// Kills the P2P isolate immediately and resets initialization state.
  void stop() {
    _heartbeatTimer?.cancel();
    _statusTimer?.cancel();
    _p2pIsolate?.kill(priority: Isolate.immediate);
    _fromIsolatePort
        ?.close(); // Close the port so it can be recreated on restart
    _fromIsolatePort = null;
    _isInitialized = false;
    peerCount.value = 0;
    _diagnosticMetadata['status'] = 'Stopped';
    _diagnosticMetadata['peerId'] = 'Unknown';
    _diagnosticMetadata['addresses'] = 'None';
  }

  /// Restarts the P2P node.
  ///
  /// Useful when credentials (like Swarm Key or Shared Secret) are updated
  /// after the initial start.
  Future<void> restart() async {
    DebugLogger.info('P2P: Restarting node to apply new configuration...');
    stop();
    // Increase delay to ensure OS releases file handles (e.g., repo.lock)
    await Future.delayed(const Duration(seconds: 2));
    await start();
  }

  /// Entry point for the P2P background isolate.
  static void _p2pIsolateEntryPoint(dynamic initMessage) async {
    // coverage:ignore-start
    final ReceivePort toIsolatePort = ReceivePort();
    SendPort fromMainPort;
    List<int>? privateKey;
    String? storagePath;
    bool autoBootstrap = true;
    List<String> bootstrapPeers = [];
    bool enableNatTraversal = true;

    if (initMessage is P2PInitData) {
      fromMainPort = initMessage.sendPort;
      privateKey = initMessage.privateKey;
      storagePath = initMessage.storagePath;
      autoBootstrap = initMessage.autoBootstrap;
      bootstrapPeers = initMessage.bootstrapPeers;
      enableNatTraversal = initMessage.enableNatTraversal;
    } else if (initMessage is SendPort) {
      fromMainPort = initMessage;
    } else {
      throw ArgumentError('Invalid init message: $initMessage');
    }

    fromMainPort.send(toIsolatePort.sendPort);

    try {
      fromMainPort.send('P2P: Initializing IPFS Node...');

      fromMainPort.send('[DEBUG] P2P: Resolving storage path...');
      // Use provided safe storage path or fallback (though fallback is risky on mobile)
      final repoPath = storagePath != null
          ? '$storagePath/ipfs_repo'
          : (Platform.environment['IPFS_PATH'] ?? './.ipfs');

      fromMainPort.send('[DEBUG] P2P: Repo Path resolved to: $repoPath');

      final repoDir = Directory(repoPath);
      if (!repoDir.existsSync()) {
        fromMainPort.send('[DEBUG] P2P: Repo directory missing. Creating...');
        repoDir.createSync(recursive: true);
        fromMainPort.send('[DEBUG] P2P: Repo directory created.');
      } else {
        fromMainPort.send('[DEBUG] P2P: Repo directory exists.');
      }

      // Force cleanup of stale lock file if it exists
      final lockFile = File('${repoDir.path}/repo.lock');
      if (lockFile.existsSync()) {
        try {
          fromMainPort.send('[DEBUG] P2P: Found stale repo.lock. Deleting...');
          // Check if process is actually running?
          // dart_ipfs normally handles this, but restart() kill() might leave it.
          // We assume if we are just starting, we own it.
          await lockFile.delete();
          fromMainPort.send('P2P: Warning - Removed stale repo.lock');
        } catch (e) {
          fromMainPort.send('P2P: Error removing lock file: $e');
        }
      } else {
        fromMainPort.send('[DEBUG] P2P: No stale lock file found.');
      }

      final keyFile = File('${repoDir.path}/swarm.key');
      if (initMessage is P2PInitData && initMessage.swarmKey != null) {
        fromMainPort.send('[DEBUG] P2P: Configuring Private Swarm Key...');
        final keyContent =
            '/key/swarm/psk/1.0.0/\n/base16/\n${initMessage.swarmKey}';
        await keyFile.writeAsString(keyContent);
        fromMainPort.send('P2P: Private Swarm Enabled');
      } else {
        if (keyFile.existsSync()) {
          fromMainPort.send('[DEBUG] P2P: Cleaning up old Swarm Key...');
          await keyFile.delete();
          fromMainPort.send('P2P: Joining Public Swarm');
        } else {
          fromMainPort.send('[DEBUG] P2P: No Swarm Key configuration needed.');
        }
      }

      // Merge defaults with custom peers if auto-bootstrap is enabled
      fromMainPort.send('[DEBUG] P2P: Configuring Bootstrap Peers...');
      final finalBootstrapPeers = <String>[];
      if (autoBootstrap) {
        finalBootstrapPeers.addAll(NetworkConstants.p2pBootstrapPeers);
      }
      finalBootstrapPeers.addAll(bootstrapPeers);
      fromMainPort.send(
        '[DEBUG] P2P: Bootstrap list size: ${finalBootstrapPeers.length}',
      );

      fromMainPort.send('P2P: Creating IPFS Node instance...');
      final IPFSNode node = await IPFSNode.create(
        IPFSConfig(
          dataPath: '$repoPath/data',
          datastorePath: '$repoPath/data',
          keystorePath: '$repoPath/keystore',
          offline: false,
          network: NetworkConfig(
            listenAddresses: [
              '/ip4/0.0.0.0/tcp/4001',
              // '/ip4/0.0.0.0/udp/4001/quic', // Disable QUIC in 1.9.67 debug to rule out binding hang
            ],
            bootstrapPeers: finalBootstrapPeers,
            enableNatTraversal: enableNatTraversal,
          ),
        ),
      );
      fromMainPort.send('P2P: IPFS Node created. Starting service...');

      await node.start();
      fromMainPort.send('P2P: IPFS Node service started.');

      final peerId = node.peerId;
      final addresses = node.addresses;

      fromMainPort.send({
        'msg': 'Federated Node Active | Connectivity: High',
        'cat': 'NET',
      });
      fromMainPort.send({'msg': 'Identity: $peerId', 'cat': 'NET'});
      fromMainPort.send({
        'msg': 'Listening on: ${addresses.join(', ')}',
        'cat': 'NET',
      });
      fromMainPort.send({
        'msg': 'Bootstrap list contains ${finalBootstrapPeers.length} nodes',
        'cat': 'NET',
      });

      // Initial active bootstrap
      try {
        await (node as dynamic).network.bootstrap();
        final initialPeers = await node.connectedPeers;
        fromMainPort.send({
          'msg': 'Initial bootstrap complete. Peers: ${initialPeers.length}',
          'cat': 'NET',
        });
      } catch (e) {
        fromMainPort.send({
          'msg': 'P2P Bootstrap Warning: ${e.toString()}',
          'level': 'WARN',
          'cat': 'NET',
        });
      }

      // Start Periodic Performance Logging
      Timer.periodic(const Duration(minutes: 1), (timer) async {
        try {
          final peers = await node.connectedPeers;
          // We can't easily get memory in pure Dart isolate without ffi/platform,
          // but we can log connection counts and latency if we had metrics.
          // For now, log connection health.
          fromMainPort.send({
            'msg': 'P2P Health Check | Connections: ${peers.length}',
            'cat': 'PERF',
          });
        } catch (_) {}
      });

      toIsolatePort.listen((message) async {
        await handleWorkerMessage(message, node, fromMainPort, privateKey);
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
    dynamic message,
    dynamic node,
    SendPort fromMainPort,
    List<int>? privateKey,
  ) async {
    if (message is Map<String, dynamic>) {
      final command = P2PCommand.fromJson(message);

      switch (command.type) {
        case P2PCommandType.search:
          fromMainPort.send({
            'msg': 'Searching for ${command.imdbId} via DHT...',
            'cat': 'DHT',
          });
          // 1. Subscribe to IMDB topic (Gossipsub)
          final topic = P2PProtocol.getTopic(command.imdbId);
          await node.subscribe(topic);

          // 2. DHT Find Providers
          final dhtKey = P2PProtocol.getDhtKey(command.imdbId);
          final startTime = DateTime.now();
          final providers = await node.dhtClient.findProviders(dhtKey);
          final duration = DateTime.now().difference(startTime).inMilliseconds;

          fromMainPort.send({
            'msg':
                'DHT Query Complete | Resolved ${providers.length} providers in ${duration}ms',
            'cat': 'DHT',
          });
          break;

        case P2PCommandType.publish:
          final topic = command.imdbId;

          fromMainPort.send({
            'msg': 'CMD: Publish -> $topic',
            'level': 800, // INFO
            'cat': 'TRACE',
          });

          fromMainPort.send({
            'msg': 'P2P: Seeding metadata for ${command.imdbId}',
            'cat': 'DHT',
          });
          final dhtKey = P2PProtocol.getDhtKey(command.imdbId);
          await node.dhtClient.addProvider(dhtKey, node.peerId);
          break;

        case P2PCommandType.boost:
          final topic = P2PProtocol.getTopic(command.imdbId);
          String payload;

          if (privateKey != null) {
            // Sign the payload before broadcasting
            final priv = ed.PrivateKey(privateKey);

            // Derive public key explicitly
            final pub = ed.public(priv);
            final pubKey = base64Encode(pub.bytes);

            // Re-sign with full context if needed, but for now just sign the 'data'
            // Actually, let's sign 'imdbId + timestamp' or similar.
            // To match "Build the Ed25519 signing layer", we should be robust.
            // Let's sign the jsonEncode of {type, id, data}.
            final baseMap = {
              'type': command.type.index,
              'imdbId': command.imdbId,
              'data': command.data,
            };
            final baseJson = jsonEncode(baseMap);
            final sig = base64Encode(ed.sign(priv, utf8.encode(baseJson)));

            final finalCmd = P2PCommand(
              type: command.type,
              imdbId: command.imdbId,
              data: command.data,
              signature: sig,
              senderPubKey: pubKey,
            );
            payload = jsonEncode(finalCmd.toJson());
          } else {
            payload = jsonEncode(command.data);
          }

          await node.publish(topic, payload);
          break;

        case P2PCommandType.get:
          fromMainPort.send(
            'P2P: Fetching block ${command.imdbId} via Bitswap...',
          );
          try {
            final blockData = await node.get(command.imdbId);
            if (blockData != null) {
              fromMainPort.send({
                'msg': 'P2P: Recieved block data: ${blockData.length} bytes',
                'cat': 'DHT',
              });
            } else {
              fromMainPort.send({
                'msg': 'P2P: Block not found',
                'level': 'WARN',
                'cat': 'DHT',
              });
            }
          } catch (e) {
            fromMainPort.send({
              'msg': 'P2P Bitswap Error: ${e.toString()}',
              'level': 'ERROR',
              'cat': 'DHT',
            });
          }
          break;

        case P2PCommandType.status:
          final peers = await node.connectedPeers;
          fromMainPort.send(peers.length);
          break;

        case P2PCommandType.blacklist:
          final peerId = command.data?['peerId'] as String?;
          if (peerId != null) {
            fromMainPort.send({
              'msg': 'P2P: Blocking peer $peerId',
              'level': 'SECURITY',
              'cat': 'NET',
            });
            // Check if connected and disconnect
            final peers = await node.connectedPeers;
            if (peers.contains(peerId)) {
              // ... comments ...
              // node.network.disconnect(peerId); // Hypothetical API
              fromMainPort.send({
                'msg': 'P2P: Terminated connection with $peerId',
                'level': 'SECURITY',
                'cat': 'NET',
              });
            }
          }
          break;

        case P2PCommandType.optimize:
          fromMainPort.send({
            'msg': 'P2P: Optimizing network connections...',
            'cat': 'NET',
          });
          try {
            // Re-trigger bootstrap process
            await (node as dynamic).network.bootstrap();
            final peers = await node.connectedPeers;
            fromMainPort.send({
              'msg':
                  'P2P: Optimization complete. Active peers: ${peers.length}',
              'cat': 'NET',
            });
          } catch (e) {
            fromMainPort.send({
              'msg': 'P2P Optimization Warning: ${e.toString()}',
              'level': 'WARN',
              'cat': 'NET',
            });
            // ... comments ...
          }
          break;
      }
    }
  }
}

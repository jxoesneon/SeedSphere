import 'dart:convert';
import 'package:crypto/crypto.dart';

/// P2P command types for swarm communication.
///
/// Defines the available command types that can be sent over the P2P network
/// for coordinating metadata discovery and stream sharing.
enum P2PCommandType {
  /// Search for streams by IMDB ID (request metadata from peers).
  search,

  /// Publish stream metadata to the swarm (respond to searches).
  publish,

  /// Boost a search  request (increase priority/urgency).
  boost,

  /// Query swarm status and peer information.
  status,

  /// Retrieve specific data from DHT or peers.
  get,

  /// Blacklist a peer and terminate connection.
  blacklist,

  /// Force immediate re-bootstrap and optimization of network connections.
  optimize,
}

/// A command sent over the P2P network.
///
/// Commands are JSON-serializable messages exchanged between peers
/// for coordinating stream metadata discovery.
///
/// Example:
/// ```dart
/// // Search for streams
/// final searchCmd = P2PCommand(
///   type: P2PCommandType.search,
///   imdbId: 'tt1234567',
///   data: {'quality': '1080p'},
/// );
///
/// // Publish metadata
/// final publishCmd = P2PCommand(
///   type: P2PCommandType.publish,
///   imdbId: 'tt1234567',
///   data: {'streams': [...]},
/// );
/// ```
class P2PCommand {
  /// The type of command being sent.
  final P2PCommandType type;

  /// The IMDB ID this command relates to (e.g., 'tt1234567').
  final String imdbId;

  /// Optional additional data payload (command-specific).
  final Map<String, dynamic>? data;

  /// The cryptographic signature of the command (Ed25519).
  final String? signature;

  /// The public key of the sender (Base64).
  final String? senderPubKey;

  /// Creates a new P2P command.
  ///
  /// [type] - The command type.
  /// [imdbId] - The target IMDB ID.
  /// [data] - Optional payload data.
  /// [signature] - Optional Ed25519 signature.
  /// [senderPubKey] - Optional sender public key.
  P2PCommand({
    required this.type,
    required this.imdbId,
    this.data,
    this.signature,
    this.senderPubKey,
  });

  /// Serializes this command to JSON for network transmission.
  ///
  /// Returns a JSON map with 'type' (as integer index), 'imdbId', 'data', 'sig', and 'pub'.
  Map<String, dynamic> toJson() => {
    'type': type.index,
    'imdbId': imdbId,
    'data': data,
    if (signature != null) 'sig': signature,
    if (senderPubKey != null) 'pub': senderPubKey,
  };

  /// Deserializes a P2P command from JSON.
  ///
  /// [json] - The JSON map received from the network.
  ///
  /// Returns a reconstructed [P2PCommand] instance.
  static P2PCommand fromJson(Map<String, dynamic> json) {
    return P2PCommand(
      type: P2PCommandType.values[json['type']],
      imdbId: json['imdbId'],
      data: json['data'],
      signature: json['sig'],
      senderPubKey: json['pub'],
    );
  }
}

/// Protocol utilities for P2P topic and DHT key generation.
///
/// Provides deterministic topic names and DHT keys for consistent
/// peer discovery and message routing across the swarm.
///
/// Example:
/// ```dart
/// final topic = P2PProtocol.getTopic('tt1234567');
/// // Returns: 'ss/v1/meta/tt1234567'
///
/// final dhtKey = P2PProtocol.getDhtKey('tt1234567');
/// // Returns: SHA-256 hash of 'ss:stream:v1:tt1234567'
/// ```
class P2PProtocol {
  /// Generates a Gossipsub topic name for an IMDB ID.
  ///
  /// [imdbId] - The IMDB identifier (e.g., 'tt1234567').
  ///
  /// Returns a topic string in the format `ss/v1/meta/{imdbId}`.
  /// All peers interested in this content subscribe to this topic.
  static String getTopic(String imdbId) => 'ss/v1/meta/$imdbId';

  /// Generates a deterministic DHT key for storing/retrieving stream metadata.
  ///
  /// [imdbId] - The IMDB identifier.
  ///
  /// Returns a SHA-256 hash of `ss:stream:v1:${imdbId}` as a hex string.
  /// This key is used for DHT PUT/GET operations in the distributed hash table.
  static String getDhtKey(String imdbId) {
    final bytes = utf8.encode('ss:stream:v1:$imdbId');
    return sha256.convert(bytes).toString();
  }
}

/// Initialization data passed to the P2P isolate spawned by P2PManager.
class P2PInitData {
  /// The SendPort to communicate back to the main isolate.
  final dynamic
  sendPort; // Use dynamic to avoid import issues or cast later, but SendPort is in isolate.

  /// The private key bytes (Ed25519) for signing.
  final List<int> privateKey;

  /// The root storage path for the IPFS repository.
  final String storagePath;

  /// Whether to use default bootstrap nodes.
  final bool autoBootstrap;

  /// Custom bootstrap nodes to use.
  final List<String> bootstrapPeers;

  /// Whether to enable NAT traversal.
  final bool enableNatTraversal;

  /// Whether to actively search for more peers.
  final bool scrapeSwarm;

  /// Maximum peers to query during swarm scraping.
  final int swarmTopN;

  /// Optional private swarm key. If null, joins public network.
  final String? swarmKey;

  P2PInitData({
    required this.sendPort,
    required this.privateKey,
    required this.storagePath,
    this.autoBootstrap = true,
    this.bootstrapPeers = const [],
    this.enableNatTraversal = true,
    this.scrapeSwarm = true,
    this.swarmTopN = 20,
    this.swarmKey,
  });
}

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

  /// Creates a new P2P command.
  ///
  /// [type] - The command type.
  /// [imdbId] - The target IMDB ID.
  /// [data] - Optional payload data.
  P2PCommand({
    required this.type,
    required this.imdbId,
    this.data,
  });

  /// Serializes this command to JSON for network transmission.
  ///
  /// Returns a JSON map with 'type' (as integer index), 'imdbId', and 'data'.
  Map<String, dynamic> toJson() => {
        'type': type.index,
        'imdbId': imdbId,
        'data': data,
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

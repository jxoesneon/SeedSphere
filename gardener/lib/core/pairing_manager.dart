import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/p2p/p2p_protocol.dart';
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:http/http.dart' as http;

/// Manages device pairing and server-side linking for authenticated communication.
class PairingManager {
  /// The P2P manager for network communication.
  final P2PManager p2p;
  final SecurityManager _security;
  final http.Client _client;

  /// Creates a [PairingManager] instance.
  PairingManager(this.p2p, {SecurityManager? security, http.Client? client})
      : _security = security ?? SecurityManager(),
        _client = client ?? http.Client();

  /// Generates a base64-encoded pairing payload containing credentials.
  ///
  /// [debridKey] - The Real-Debrid API key to share.
  /// [gardenerId] - The gardener ID of the sharing device.
  ///
  /// Returns a base64-encoded JSON payload suitable for QR code encoding.
  ///
  /// **Payload structure:**
  /// ```json
  /// {
  ///   "gardenerId": "gardener-xyz",
  ///   "debridKey": "ABC123...",
  ///   "timestamp": 1234567890
  /// }
  /// ```
  String generatePairingPayload(String debridKey, String gardenerId) {
    final payload = {
      'gardenerId': gardenerId,
      'debridKey': debridKey,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  /// Starts listening for pairing responses on a unique pairing topic.
  ///
  /// [pairingId] - A unique identifier for this pairing session (e.g., short code).
  ///
  /// Sends a "boost" command to the P2P network signaling readiness to pair.
  /// Other devices can respond to this specific pairing topic.
  void startPairingListener(String pairingId) {
    // Listen to the unique pairing topic in the Gossipsub swarm
    p2p.sendCommand(P2PCommand(
      type: P2PCommandType.boost, // Reusing boost for signaling
      imdbId: 'pairing:$pairingId',
      data: {'status': 'waiting'},
    ));
  }

  /// Completes the pairing process by decoding and storing received credentials.
  ///
  /// [payloadBase64] - The base64-encoded payload received from the sharing device.
  ///
  /// Decodes the payload, extracts credentials, and stores them in [LocalKMS].
  ///
  /// **Note:** Current implementation only logs the pairing. Production version
  /// should actually store credentials via [LocalKMS].
  Future<void> completePairing(String payloadBase64) async {
    final decoded = jsonDecode(utf8.decode(base64Decode(payloadBase64)));
    // TODO: Store the received credentials in LocalKMS
    debugPrint(
        'PAIRING: Successfully paired via P2P with ${decoded['gardenerId']}');
  }

  /// Requests a linking token from the Federated Router.
  /// Used for HMAC-based authentication setup.
  Future<String?> requestLinkingToken() async {
    final gardenerId = p2p.gardenerId;
    if (gardenerId == null) return null;

    try {
      const baseUrl = 'https://seedsphere-router.fly.dev';
      final response = await _client.post(
        Uri.parse('$baseUrl/api/linking/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gardener_id': gardenerId,
          'platform': defaultTargetPlatform.name
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
    } catch (e) {
      debugPrint('LINKING: Request token failed: $e');
    }
    return null;
  }

  /// Polls the Router to complete the linking process and obtain the secret.
  Future<bool> completeLinkingWithToken(String token) async {
    try {
      const baseUrl = 'https://seedsphere-router.fly.dev';
      final response = await _client.post(
        Uri.parse('$baseUrl/api/linking/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'seedling_id': 'mobile-app'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final secret = data['secret'] as String;
        await _security.setSharedSecret(secret);
        debugPrint('LINKING: Successfully linked with Router. Secret stored.');
        return true;
      }
    } catch (e) {
      debugPrint('LINKING: Complete linking failed: $e');
    }
    return false;
  }
}

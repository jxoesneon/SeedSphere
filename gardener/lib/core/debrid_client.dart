import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/local_kms.dart';

/// Client for interacting with the Real-Debrid API.
///
/// This client provides a high-level interface to the Real-Debrid REST API,
/// handling authentication, magnet link conversion, and unrestricted link generation.
///
/// The client uses [LocalKMS] for secure API key storage and retrieval.
/// All API requests require a valid Real-Debrid API key.
///
/// Example:
/// ```dart
/// final client = DebridClient();
///
/// // Add a magnet link
/// final result = await client.addMagnet('magnet:?xt=urn:btih:...');
/// final torrentId = result['id'];
///
/// // Unrestrict a download link
/// final link = await client.unrestrictLink('https://example.com/file');
/// final directUrl = link['download'];
/// ```
class DebridClient {
  final LocalKMS _kms;
  final http.Client _client;
  static const _baseUrl = 'https://api.real-debrid.com/rest/1.0';

  /// Creates a new [DebridClient] instance.
  ///
  /// [kms] - Optional key management system. Defaults to new [LocalKMS] instance.
  /// [client] - Optional HTTP client for testing. Defaults to standard HTTP client.
  DebridClient({LocalKMS? kms, http.Client? client})
      : _kms = kms ?? LocalKMS(),
        _client = client ?? http.Client();

  /// Retrieves the stored Real-Debrid API key from secure storage.
  ///
  /// Returns the API key if found, null otherwise.
  Future<String?> _getApiKey() async => await _kms.getDebridKey();

  /// Fetches the current user's account information.
  ///
  /// Returns a map containing user details including username, email,
  /// premium status, and expiration date.
  ///
  /// Throws [Exception] if no API key is configured or if the request fails.
  ///
  /// Example response:
  /// ```dart
  /// {
  ///   'id': 12345,
  ///   'username': 'user123',
  ///   'email': 'user@example.com',
  ///   'points': 1000,
  ///   'premium': 1234567890
  /// }
  /// ```
  Future<Map<String, dynamic>> getUser() async {
    final token = await _getApiKey();
    if (token == null) throw Exception('No Debrid API Key found');

    final response = await _client.get(
      Uri.parse('$_baseUrl/user'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user: ${response.statusCode}');
    }
  }

  /// Adds a magnet link to the Real-Debrid account.
  ///
  /// [magnet] - The magnet URI to add (must start with 'magnet:?xt=urn:btih:').
  ///
  /// Returns a map containing the torrent ID and status information.
  ///
  /// Throws [Exception] if no API key is configured or if the magnet is invalid.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.addMagnet('magnet:?xt=urn:btih:...');
  /// print('Torrent ID: ${result['id']}');
  /// ```
  Future<Map<String, dynamic>> addMagnet(String magnet) async {
    final token = await _getApiKey();
    if (token == null) throw Exception('No Debrid API Key found');

    final response = await _client.post(
      Uri.parse('$_baseUrl/torrents/addMagnet'),
      headers: {'Authorization': 'Bearer $token'},
      body: {'magnet': magnet},
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add magnet: ${response.statusCode}');
    }
  }

  /// Converts a restricted link to an unrestricted direct download link.
  ///
  /// [link] - The restricted link to unrestrict (e.g., from a file host).
  ///
  /// Returns a map containing the direct download URL and file information.
  ///
  /// Throws [Exception] if no API key is configured or if the link cannot be unrestricted.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.unrestrictLink('https://host.com/file');
  /// final directUrl = result['download'];
  /// final filename = result['filename'];
  /// ```
  Future<Map<String, dynamic>> unrestrictLink(String link) async {
    final token = await _getApiKey();
    if (token == null) throw Exception('No Debrid API Key found');

    final response = await _client.post(
      Uri.parse('$_baseUrl/unrestrict/link'),
      headers: {'Authorization': 'Bearer $token'},
      body: {'link': link},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to unrestrict link: ${response.body}');
    }
  }
}

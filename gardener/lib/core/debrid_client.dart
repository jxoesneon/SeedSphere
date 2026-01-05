import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gardener/core/local_kms.dart';
import 'package:gardener/core/network_constants.dart';

/// Client for interacting with the Real-Debrid API.
///
/// This client provides a high-level interface to the Real-Debrid REST API,
/// handling authentication, magnet link conversion, and unrestricted link generation.
///
/// The client uses [LocalKMS] for secure API key storage and retrieval.
/// All API requests require a valid Real-Debrid API key.
class DebridClient {
  final LocalKMS _kms;
  final http.Client _client;
  static const _baseUrl = NetworkConstants.debridApiBase;

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

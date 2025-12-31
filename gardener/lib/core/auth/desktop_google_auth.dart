import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Handles Google Authentication for Desktop platforms (Windows/Linux/macOS)
/// using the Loopback IP Address flow (RF 8252).
class DesktopGoogleAuth {
  // TODO: The user must configure this Client ID in their code or config.
  // We use a placeholder that clearly indicates what is needed.
  static const String _clientId =
      'YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com';

  // Scopes required
  static const List<String> _scopes = ['email', 'profile', 'openid'];

  /// Starts the authentication flow.
  /// Returns the `idToken` if successful, or null.
  static Future<String?> signIn() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return _performLoopbackAuth();
    }
    throw UnsupportedError('DesktopGoogleAuth is only for Desktop platforms.');
  }

  static Future<String?> _performLoopbackAuth() async {
    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    try {
      // 1. Start local loopback server
      // Use loopbackIPv4 (127.0.0.1) as recommended by Google to avoid IPv6 issues
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/callback';

      // 2. Construct OAuth URL
      final scopeString = _scopes.join(' ');

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopeString,
        'access_type': 'online',
        'state': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // 3. Launch Browser
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        await server.close();
        return null;
      }

      // 4. Wait for callback
      final completer = Completer<String?>();

      sub = server.listen((request) async {
        if (request.uri.path == '/callback') {
          final authCode = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(
              '<html><head><title>Auth Complete</title></head><body style="background:#1a1a1a;color:white;font-family:sans-serif;text-align:center;padding:50px;"><h1>Signed In!</h1><p>You can close this window and return to SeedSphere.</p><script>window.close();</script></body></html>',
            );
          await request.response.close();

          if (authCode != null) {
            completer.complete(authCode);
          } else {
            completer.completeError('Auth failed: $error');
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      // Race between timeout and auth code capture
      String? authCode;
      try {
        authCode = await completer.future.timeout(const Duration(minutes: 2));
      } catch (e) {
        debugPrint('Auth Timeout or Error: $e');
        authCode = null;
      } finally {
        await sub.cancel();
        await server.close();
      }

      if (authCode != null) {
        // 5. Exchange Code for ID Token
        return await _exchangeCodeForIdToken(authCode, redirectUri);
      }

      return null;
    } catch (e) {
      debugPrint('Desktop Auth Error: $e');
      if (sub != null) await sub.cancel();
      if (server != null) await server.close();
      return null;
    }
  }

  static Future<String?> _exchangeCodeForIdToken(
    String code,
    String redirectUri,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'code': code,
          'client_id': _clientId,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id_token'] as String?;
      } else {
        debugPrint('Token Exchange Failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Token Exchange Error: $e');
      return null;
    }
  }
}

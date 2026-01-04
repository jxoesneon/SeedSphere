import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Handles Google Authentication for Desktop platforms (Windows/Linux/macOS)
/// using the Loopback IP Address flow (RF 8252) with PKCE Security.
class DesktopGoogleAuth {
  // Desktop Client ID provided by user.
  static const String _clientId =
      '550711161426-lk1vk3hf44amas66mk22dvv1235673uk.apps.googleusercontent.com';

  // Secret is now injected via --dart-define in launch.json
  static const String _clientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
  );

  static const List<String> _scopes = ['email', 'profile', 'openid'];

  /// Starts the authentication flow.
  /// Returns the `idToken` if successful.
  static Future<String?> signIn() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return _performLoopbackAuth();
    }
    throw UnsupportedError('DesktopGoogleAuth is only for Desktop platforms.');
  }

  static Future<String?> _performLoopbackAuth() async {
    if (_clientSecret.isEmpty) {
      throw StateError(
        'Google Client Secret is missing. Run with --dart-define=GOOGLE_CLIENT_SECRET=...',
      );
    }
    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    try {
      // 1. Generate PKCE Verifier and Challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // 2. Start local loopback server
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/callback';

      // 3. Construct OAuth URL with PKCE
      final scopeString = _scopes.join(' ');

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopeString,
        'access_type': 'online',
        'state': DateTime.now().millisecondsSinceEpoch.toString(),
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      // 4. Launch Browser
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        await server.close();
        throw Exception('Could not launch browser for auth.');
      }

      // 5. Wait for callback
      final completer = Completer<String?>();

      sub = server.listen((request) async {
        if (request.uri.path == '/callback') {
          final authCode = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          // Serve a nice close-window page
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(
              '<html><head><title>Auth Complete</title></head><body style="background:#0a0a0a;color:white;font-family:sans-serif;text-align:center;padding:50px;"><h1>Signed In!</h1><p>Return to SeedSphere to continue.</p><script>window.close();</script></body></html>',
            );
          await request.response.close();

          if (authCode != null) {
            completer.complete(authCode);
          } else {
            completer.completeError('Auth callback returned error: $error');
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      // Race between timeout and auth code capture
      String? authCode;
      try {
        authCode = await completer.future.timeout(const Duration(minutes: 5));
      } catch (e) {
        throw Exception('Timed out waiting for browser login. ($e)');
      } finally {
        await sub.cancel();
        await server.close();
      }

      if (authCode != null) {
        // 6. Exchange Code for ID Token using PKCE
        return await _exchangeCodeForIdToken(
          authCode,
          redirectUri,
          codeVerifier,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Desktop Auth Error: $e');
      rethrow; // Propagate error to UI
    } finally {
      if (sub != null) await sub.cancel();
      if (server != null) await server.close();
    }
  }

  static Future<String?> _exchangeCodeForIdToken(
    String code,
    String redirectUri,
    String codeVerifier,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id_token'] as String?;
      } else {
        // Log detailed error for debugging logic
        final err = 'Token fail: ${response.statusCode} - ${response.body}';
        debugPrint(err);
        throw Exception(err);
      }
    } catch (e) {
      debugPrint('Token Exchange Error: $e');
      rethrow;
    }
  }

  // --- PKCE Helpers ---

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

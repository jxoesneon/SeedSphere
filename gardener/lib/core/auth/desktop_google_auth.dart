import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/debug_config.dart';

/// Handles Google Authentication for Desktop platforms (Windows/Linux/macOS)
/// using the Loopback IP Address flow (RF 8252) with PKCE Security.
class DesktopGoogleAuth {
  // --- Credentials Configuration ---

  // Production Credentials
  static const String _prodClientId =
      '550711161426-lk1vk3hf44amas66mk22dvv1235673uk.apps.googleusercontent.com';

  // Development Credentials (IDs are public, Secrets are not)
  static const String _devClientId =
      '550711161426-cc2iqb8h08thae6hqfshhfv2i22bgl1c.apps.googleusercontent.com';

  static const String _devClientSecret = '';

  /// Returns the Client ID to use.
  /// Priority:
  /// 1. --dart-define=GOOGLE_CLIENT_ID=... (Compile Time)
  /// 2. GOOGLE_CLIENT_ID (Runtime Env)
  /// 3. Debug Mode -> Dev ID
  /// 4. Release Mode -> Prod ID
  static String get _clientId {
    const envId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (envId.isNotEmpty) return envId;

    final platformId = Platform.environment['GOOGLE_CLIENT_ID'];
    if (platformId != null && platformId.isNotEmpty) return platformId;

    return kDebugMode ? _devClientId : _prodClientId;
  }

  /// Returns the Client Secret to use.
  /// Priority:
  /// 1. --dart-define=GOOGLE_CLIENT_SECRET=... (Compile Time)
  /// 2. GOOGLE_CLIENT_SECRET (Runtime Env)
  /// 3. Debug Mode -> Dev Secret
  /// 4. Release Mode -> Empty
  static String get _clientSecret {
    const envSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
    if (envSecret.isNotEmpty) return envSecret;

    final platformSecret = Platform.environment['GOOGLE_CLIENT_SECRET'];
    if (platformSecret != null && platformSecret.isNotEmpty) {
      return platformSecret;
    }

    return kDebugMode ? _devClientSecret : '';
  }

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
    if (DebugConfig.authGated) {
      DebugLogger.debug(
        'Auth: [Trace] Entering _performLoopbackAuth',
        category: 'AUTH',
      );
    }
    DebugLogger.info('Auth: Starting Desktop Loopback Auth', category: 'AUTH');

    // Check Secret
    final hasSecret = _clientSecret.isNotEmpty;
    if (DebugConfig.authGated) {
      DebugLogger.debug(
        'Auth: [Trace] Has Client Secret: $hasSecret',
        category: 'AUTH',
      );
    }

    if (!hasSecret) {
      if (DebugConfig.authGated) {
        DebugLogger.error(
          'Auth: [Error] Client Secret is MISSING',
          category: 'AUTH',
        );
      }
      throw StateError(
        'Google Client Secret is missing. Run with --dart-define=GOOGLE_CLIENT_SECRET=...',
      );
    }

    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    try {
      // 1. Generate PKCE Verifier and Challenge
      if (DebugConfig.authGated) {
        DebugLogger.debug('Auth: [Trace] Generating PKCE...', category: 'AUTH');
      }
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // 2. Start local loopback server
      if (DebugConfig.authGated) {
        DebugLogger.debug(
          'Auth: [Trace] Binding loopback server...',
          category: 'AUTH',
        );
      }

      // Determine configuration based on Client ID type
      // Dev ID (Web Type) requires fixed port 5000 and /auth/callback
      // Prod ID (Desktop Type) supports ephemeral ports (0) and /callback
      final isDevId = _clientId == _devClientId;
      final port = isDevId ? 5001 : 0;
      final path = isDevId ? '/auth/callback' : '/callback';

      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        if (DebugConfig.authGated) {
          DebugLogger.debug(
            'Auth: [Trace] Server bound on port ${server.port}',
            category: 'AUTH',
          );
        }
      } catch (e) {
        if (DebugConfig.authGated) {
          DebugLogger.error(
            'Auth: [Error] Failed to bind port $port: $e',
            category: 'AUTH',
          );
        }
        throw Exception('Could not bind to auth port $port. Is it in use?');
      }

      final redirectUri = 'http://localhost:${server.port}$path';

      DebugLogger.info('Auth: Listening on $redirectUri', category: 'AUTH');

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
      DebugLogger.info('Auth: Launching browser...', category: 'AUTH');
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        await server.close();
        throw Exception('Could not launch browser for auth.');
      }

      // 5. Wait for callback
      final completer = Completer<String?>();

      sub = server.listen((request) async {
        if (request.uri.path == path) {
          final authCode = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          DebugLogger.info(
            'Auth: Callback received. Code present: ${authCode != null}',
            category: 'AUTH',
          );

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
    } catch (e, st) {
      if (DebugConfig.authGated) {
        DebugLogger.error(
          'Auth: [Error] Exception in loopback auth: $e',
          category: 'AUTH',
        );
        DebugLogger.error('Auth: [Error] Stack: $st', category: 'AUTH');
      }
      DebugLogger.error(
        'Desktop Auth Error',
        error: e,
        stackTrace: st,
        category: 'AUTH',
      );
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
      DebugLogger.info('Auth: Exchanging code for token...', category: 'AUTH');
      final response = await HttpLogger.post(
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
        DebugLogger.error(err, category: 'AUTH');
        throw Exception(err);
      }
    } catch (e) {
      DebugLogger.error('Token Exchange Error', error: e, category: 'AUTH');
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

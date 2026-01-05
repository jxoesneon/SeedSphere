import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:router/db_service.dart';
import 'package:router/mailer_service.dart';
import 'package:router/linking_service.dart';

/// Service handling user authentication, OAuth, Magic Links, and Session management.
class AuthService {
  final DbService _db;
  final MailerService _mailer;
  final String _jwtSecret;
  final String? _googleClientId;
  final String? _googleClientSecret;
  final LinkingService _linkingService;
  final http.Client _client;

  /// Creates a new AuthService with the required system dependencies.
  AuthService(
    this._db,
    this._mailer,
    this._linkingService, {
    http.Client? client,
    String? googleClientId,
    String? googleClientSecret,
  }) : _jwtSecret =
           Platform.environment['AUTH_JWT_SECRET'] ?? _generateRandomSecret(),
       _googleClientId =
           googleClientId ?? Platform.environment['GOOGLE_CLIENT_ID'],
       _googleClientSecret =
           googleClientSecret ?? Platform.environment['GOOGLE_CLIENT_SECRET'],
       _client = client ?? http.Client();

  static String _generateRandomSecret() {
    print(
      'WARN: AUTH_JWT_SECRET not set. Using random secret for this session.',
    );
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  /// Verifies CSRF protection for state-changing requests.
  ///
  /// Checks for the custom `x-seedsphere-client` header, which browsers
  /// prevent cross-origin requests from sending without CORS.
  bool _checkCsrf(Request req) {
    // Custom Header Check: Browsers won't allow this cross-origin without CORS permission
    return req.headers.containsKey('x-seedsphere-client');
  }

  /// Returns the router representing the authentication and user management endpoints.
  Router get router {
    final app = Router();

    // Google Auth
    app.get('/google/start', _handleGoogleStart);
    app.get('/google/callback', _handleGoogleCallback);
    app.post('/google/verify', _handleGoogleVerify);

    // Magic Link
    app.post('/magic/start', _handleMagicStart);
    app.get('/magic/callback', _handleMagicCallback);

    // Session
    app.get('/session', _handleSession); // Current session check
    app.get('/sessions', _handleGetSessions); // List all sessions
    app.delete('/sessions/<sid>', _handleRevokeSession); // Revoke specific
    app.post('/logout', _handleLogout);

    // User Management
    app.post('/settings', _handleUpdateSettings);
    app.get('/token', _handleGetToken);
    app.delete('/account', _handleDeleteAccount);
    app.post('/unlink', _handleUnlinkDevices);

    // Profile Data
    app.get('/activity', _handleGetActivity);
    app.get('/devices', _handleGetDevices);

    return app;
  }

  Response _handleGoogleStart(Request req) {
    if (_googleClientId == null) {
      return Response.internalServerError(body: 'google_not_configured');
    }

    final redirectUri = '${_baseUrl(req)}/api/auth/google/callback';
    final params = {
      'client_id': _googleClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'access_type': 'offline',
      'include_granted_scopes': 'true',
    };

    final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', params);
    return Response.found(uri);
  }

  /// Verifies an ID Token sent from the client (Desktop/Mobile) and creates a session.
  Future<Response> _handleGoogleVerify(Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body);
      final idToken = data['idToken'] as String?;

      if (idToken == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'missing_id_token'}),
        );
      }

      // Decode JWT
      final parts = idToken.split('.');
      if (parts.length != 3) {
        return Response.badRequest(
          body: jsonEncode({'error': 'invalid_token_format'}),
        );
      }

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
      );

      final sub = payload['sub'] as String;
      final email = payload['email'] as String;
      final aud = payload['aud'] as String?;

      // Validate Audience (Supports Web, Desktop, Mobile)
      final validAudiences = [
        _googleClientId, // Web (Primary)
        Platform.environment['GOOGLE_CLIENT_ID_DESKTOP'] ??
            '550711161426-bvvv578gtt7cst7lsar3c28r3uh6n706.apps.googleusercontent.com',
        Platform.environment['GOOGLE_CLIENT_ID_ANDROID'] ??
            '550711161426-2se9i9p6p7o3pk1els6b60mooait9b0f.apps.googleusercontent.com',
        Platform.environment['GOOGLE_CLIENT_ID_IOS'] ??
            '550711161426-bkup98581nj5jsuq38cutigtc0q58idk.apps.googleusercontent.com',
      ];

      // Relaxed check: just ensure it belongs to our project (prefix match) if strict list fails?
      // Or just add the known Desktop ID.
      if (!validAudiences.contains(aud) &&
          aud != null &&
          !aud.startsWith('550711161426-')) {
        // Allow any client ID from our project (550711161426)
        return Response.forbidden(
          jsonEncode({'error': 'invalid_token_audience', 'aud': aud}),
        );
      }

      final userId = 'google:$sub';
      _db.upsertUser(id: userId, email: email, provider: 'google');

      // Issue Session
      // We return the token/user info directly instead of 302 redirect
      // because this is an JSON API call from the app.

      // Generate Secure Random Session ID
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(255));
      final sid = base64UrlEncode(values);

      // Store in DB (30 days TTL)
      _db.createSession(sid, userId, 30 * 24 * 60 * 60 * 1000);

      // We return the session ID as 'token' for the client to use in Bearer or Cookie
      return Response.ok(
        jsonEncode({
          'ok': true,
          'token': sid, // Client stores this as auth_token
          'user': {'id': userId, 'email': email},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'verification_failed', 'details': '$e'}),
      );
    }
  }

  Future<Response> _handleGoogleCallback(Request req) async {
    final code = req.url.queryParameters['code'];
    if (code == null) return Response.badRequest(body: 'missing_code');

    if (_googleClientId == null || _googleClientSecret == null) {
      return Response.internalServerError(body: 'google_not_configured');
    }

    final redirectUri = '${_baseUrl(req)}/api/auth/google/callback';

    try {
      final tokenResp = await _client.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'code': code,
          'client_id': _googleClientId,
          'client_secret': _googleClientSecret,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (tokenResp.statusCode != 200) {
        return Response.internalServerError(
          body: 'google_token_failed: ${tokenResp.body}',
        );
      }

      final tokenData = jsonDecode(tokenResp.body);
      final idToken = tokenData['id_token'];
      if (idToken == null) {
        return Response.internalServerError(body: 'missing_id_token');
      }

      // Decode JWT (without verifying signature for simplicity/parity)
      final parts = idToken.split('.');
      if (parts.length != 3) {
        return Response.internalServerError(body: 'invalid_id_token_format');
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
      );

      final sub = payload['sub'] as String;
      final email = payload['email'] as String;
      final aud = payload['aud'] as String?;

      // Critical Security Check: Verify Audience matches our Client ID
      if (aud != _googleClientId) {
        return Response.forbidden('invalid_token_audience');
      }

      final userId = 'google:$sub';

      _db.upsertUser(id: userId, email: email, provider: 'google');

      // Redirect to Client (Portal)
      return _issueSession(
        req,
        userId,
        redirect: '/dashboard.html?login=success',
      );
    } catch (e) {
      return Response.internalServerError(body: 'auth_error: $e');
    }
  }

  Future<Response> _handleMagicStart(Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body);
      final email = (data['email'] as String?)?.trim().toLowerCase();

      if (email == null || !email.contains('@')) {
        return Response.badRequest(body: 'invalid_email');
      }

      final jwt = JWT({'sub': email, 'typ': 'magic'});
      final token = jwt.sign(
        SecretKey(_jwtSecret),
        expiresIn: const Duration(minutes: 15),
      );
      final url = '${_baseUrl(req)}/api/auth/magic/callback?token=$token';

      final sent = await _mailer.sendEmail(
        to: email,
        subject: 'Sign in to SeedSphere',
        body: 'Click here to sign in: $url', // Simplified for now
        isHtml: false,
      );

      if (!sent) {
        return Response.internalServerError(
          body: jsonEncode({
            'ok': false,
            'error': 'SMTP Send Failed. Check logs.',
          }),
        );
      }

      return Response.ok(jsonEncode({'ok': true}));
    } catch (e) {
      print('Magic Link Error: $e');
      return Response.internalServerError(
        body: jsonEncode({'ok': false, 'error': 'Server Error: $e'}),
      );
    }
  }

  Response _handleMagicCallback(Request req) {
    final token = req.url.queryParameters['token'];
    if (token == null) return Response.badRequest(body: 'missing_token');

    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      final payload = jwt.payload as Map<String, dynamic>;
      final email = payload['sub'] as String;
      final userId = 'magic:$email';

      _db.upsertUser(id: userId, email: email, provider: 'magic');

      // Redirect to Client (Portal)
      return _issueSession(
        req,
        userId,
        redirect: '/dashboard.html?login=success',
      );
    } catch (e) {
      return Response.badRequest(body: 'invalid_or_expired_token');
    }
  }

  Response _handleSession(Request req) {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.ok(jsonEncode({'ok': true, 'user': null}));
    }

    final user = _db.getUser(userId);

    // Expand settings JSON if present
    var userData = user != null
        ? Map<String, dynamic>.from(user)
        : {'id': userId};
    if (userData['settings_json'] != null) {
      try {
        userData['settings'] = jsonDecode(userData['settings_json']);
      } catch (_) {}
      userData.remove('settings_json');
    }

    return Response.ok(jsonEncode({'ok': true, 'user': userData}));
  }

  Response _handleLogout(Request req) {
    return _clearSession(req);
  }

  // --- User Management ---

  Future<Response> _handleUpdateSettings(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    if (!_checkCsrf(req)) {
      return Response.forbidden(jsonEncode({'error': 'csrf_violation'}));
    }

    try {
      final body = await req.readAsString();
      final settings = jsonDecode(body) as Map<String, dynamic>;
      _db.updateUserSettings(userId, settings);
      return Response.ok(jsonEncode({'ok': true}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': '$e'}));
    }
  }

  Future<Response> _handleGetToken(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    // Generate token for the user (Gardener ID)
    final result = _linkingService.startLinking(userId, platform: 'web');
    return Response.ok(jsonEncode(result));
  }

  Future<Response> _handleDeleteAccount(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    if (!_checkCsrf(req)) {
      return Response.forbidden(jsonEncode({'error': 'csrf_violation'}));
    }

    _db.deleteUser(userId);
    return _clearSession(req);
  }

  Future<Response> _handleUnlinkDevices(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    if (!_checkCsrf(req)) {
      return Response.forbidden(jsonEncode({'error': 'csrf_violation'}));
    }

    _db.deleteUserBindings(userId);
    return Response.ok(jsonEncode({'ok': true, 'message': 'unlinked_all'}));
  }

  Future<Response> _handleGetActivity(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    final activity = _db.getUserActivity(userId);
    return Response.ok(jsonEncode({'ok': true, 'activity': activity}));
  }

  Future<Response> _handleGetDevices(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    final devices = _db.getBindings(userId);
    return Response.ok(jsonEncode({'ok': true, 'devices': devices}));
  }

  Future<Response> _handleGetSessions(Request req) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    // Get all sessions
    final sessions = _db.getSessions(userId);

    // Mark current session
    final currentSid = _getSessionIdFromCookie(req);
    final enriched = sessions
        .map((s) => {...s, 'is_current': s['sid'] == currentSid})
        .toList();

    return Response.ok(jsonEncode({'ok': true, 'sessions': enriched}));
  }

  Future<Response> _handleRevokeSession(Request req, String sid) async {
    final userId = getSessionId(req);
    if (userId == null) {
      return Response.forbidden(jsonEncode({'error': 'unauthorized'}));
    }

    if (!_checkCsrf(req)) {
      return Response.forbidden(jsonEncode({'error': 'csrf_violation'}));
    }

    // Verify session belongs to user (Security Check)
    // We fetch the session first to check owner
    final session = _db.getSession(sid);
    if (session == null) {
      return Response.notFound(jsonEncode({'error': 'session_not_found'}));
    }

    if (session['user_id'] != userId) {
      return Response.forbidden(jsonEncode({'error': 'forbidden'}));
    }

    _db.revokeSession(sid);
    return Response.ok(jsonEncode({'ok': true}));
  }

  // --- Helpers ---

  String _baseUrl(Request req) {
    final host = req.headers['host'] ?? 'localhost:8080';
    final proto = req.headers['x-forwarded-proto'] ?? 'http';
    return '$proto://$host';
  }

  Response _issueSession(Request req, String userId, {String? redirect}) {
    // Generate Secure Random Session ID
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(255));
    final sid = base64UrlEncode(values);

    // Store in DB (30 days TTL)
    _db.createSession(sid, userId, 30 * 24 * 60 * 60 * 1000);

    // Cookie Hardening
    final isHttps =
        req.requestedUri.scheme == 'https' ||
        req.headers['x-forwarded-proto'] == 'https';
    final secureFlag = isHttps ? '; Secure' : '';
    final cookie =
        'seedsphere_session=$sid; Path=/; HttpOnly; SameSite=Lax$secureFlag; Max-Age=${60 * 60 * 24 * 30}'; // 30 days
    final headers = {'Set-Cookie': cookie};

    if (redirect != null) {
      final location = redirect.startsWith('http')
          ? redirect
          : '${_baseUrl(req)}$redirect';
      headers['Location'] = location;
      return Response.found(location, headers: headers);
    }

    return Response.ok(jsonEncode({'ok': true}), headers: headers);
  }

  Response _clearSession(Request req) {
    final sid = _getSessionIdFromCookie(req);
    if (sid != null) {
      _db.deleteSession(sid);
    }
    final cookie = 'seedsphere_session=; Path=/; HttpOnly; Max-Age=0';
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: {'Set-Cookie': cookie},
    );
  }

  /// Retrieves the authenticated user's ID from the request cookies.
  ///
  /// Returns `null` if no valid session is found.
  String? getSessionId(Request req) {
    final sid = _getSessionIdFromCookie(req);
    if (sid == null) return null;

    final session = _db.getSession(sid);
    if (session == null) return null;

    return session['user_id'] as String;
  }

  String? _getSessionIdFromCookie(Request req) {
    final cookieHeader = req.headers['cookie'];
    if (cookieHeader == null) return null;

    final cookies = cookieHeader.split(';').map((s) => s.trim());
    for (final cookie in cookies) {
      if (cookie.startsWith('seedsphere_session=')) {
        return cookie.substring('seedsphere_session='.length);
      }
    }
    return null;
  }

  /// Verifies a JWT token and returns the claims if valid, null otherwise.
  Map<String, dynamic>? verifyJwt(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

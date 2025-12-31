import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/haptic_manager.dart';

/// Authentication screen for SeedSphere.
///
/// Provides login options:
/// - Magic Link (email-based passwordless login)
/// - Google Sign-In
///
/// After successful authentication, user token is stored and the app
/// proceeds to the SwarmDashboard.
class AuthScreen extends StatefulWidget {
  /// Callback invoked when authentication is successful.
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _magicLinkSent = false;

  static const _apiBase = 'https://seedsphere.fly.dev';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/api/auth/magic/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _magicLinkSent = true;
          _message = 'Check your email for the magic link!';
        });
      } else {
        setState(() => _message = 'Failed to send magic link. Try again.');
      }
    } catch (e) {
      setState(() => _message = 'Network error. Check your connection.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();

      if (account == null) {
        setState(() => _message = 'Sign-in cancelled.');
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        setState(() => _message = 'Failed to get authentication token.');
        return;
      }

      // Send to backend for verification
      final response = await http.post(
        Uri.parse('$_apiBase/api/auth/google/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;

        if (token != null) {
          // Store token and extract user ID from JWT
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_email', account.email);

          // Extract user ID from JWT payload (base64 decode middle part)
          final userId = _extractUserIdFromJwt(token);
          if (userId != null) {
            await prefs.setString('user_id', userId);
          }

          unawaited(HapticManager.success());
          widget.onAuthenticated();
        } else {
          setState(() => _message = 'Authentication failed.');
        }
      } else {
        setState(() => _message = 'Server authentication failed.');
      }
    } catch (e) {
      setState(() => _message = 'Sign-in failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Extracts user ID from JWT token payload.
  String? _extractUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (middle part)
      String payload = parts[1];
      // Add padding if needed
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      // Try common JWT claims for user ID
      return payloadMap['sub'] as String? ??
          payloadMap['userId'] as String? ??
          payloadMap['user_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _skipAuth() async {
    // For development/testing: skip auth with a guest token
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', guestId);
    await prefs.setString('user_id', guestId);
    await prefs.setString('user_email', 'guest@seedsphere.app');
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  AethericTheme.deepVoid.withValues(alpha: 0.95),
                  AethericTheme.deepVoid,
                ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AethericGlass(
                  borderRadius: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo/Title
                        Text(
                          'SEEDSPHERE',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SIGN IN TO ENTER THE SWARM',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            letterSpacing: 2,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 40),

                        if (!_magicLinkSent) ...[
                          // Email input
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white54,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Magic Link button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _sendMagicLink,
                              icon: const Icon(Icons.mail_outline),
                              label: Text(
                                _isLoading ? 'SENDING...' : 'SEND MAGIC LINK',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AethericTheme.aetherBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Google Sign-In button (Mobile Only)
                          if (!kIsWeb &&
                              (defaultTargetPlatform == TargetPlatform.iOS ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.android))
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _signInWithGoogle,
                                icon: Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.g_mobiledata, size: 24),
                                ),
                                label: const Text(
                                  'CONTINUE WITH GOOGLE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          // Magic link sent confirmation
                          const Icon(
                            Icons.mark_email_read_outlined,
                            size: 64,
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Check your email!',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click the link we sent to complete sign-in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () =>
                                setState(() => _magicLinkSent = false),
                            child: const Text('Use a different email'),
                          ),
                        ],

                        // Message display
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _message!.contains('Check')
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontSize: 14,
                            ),
                          ),
                        ],

                        // Skip for development (only in debug mode)
                        if (kDebugMode) ...[
                          const SizedBox(height: 32),
                          TextButton(
                            onPressed: _skipAuth,
                            child: Text(
                              'Skip (Debug Only)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

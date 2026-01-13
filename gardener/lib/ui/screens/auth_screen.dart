import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gardener/core/auth/desktop_google_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:gardener/core/haptic_manager.dart';
import 'package:gardener/core/network_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/p2p/p2p_manager.dart';
import 'package:gardener/core/security_manager.dart';
import 'package:gardener/core/debug_logger.dart';
import 'package:gardener/core/debug_config.dart';

/// Authentication screen for SeedSphere.
///
/// Provides login options:
/// - Magic Link (email-based passwordless login)
/// - Google Sign-In
///
/// After successful authentication, user token is stored and the app
/// proceeds to the SwarmDashboard.
class AuthScreen extends ConsumerStatefulWidget {
  /// Callback invoked when authentication is successful.
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _magicLinkSent = false;

  String get _apiBase => NetworkConstants.apiBase;

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

    DebugLogger.info('Auth: Sending Magic Link to $email', category: 'AUTH');

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final response = await HttpLogger.post(
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
        String errorMsg = 'Failed to send magic link.';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) {
            errorMsg = '${data['error']}';
          }
        } catch (_) {}
        setState(() => _message = '$errorMsg Try again.');
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

    if (DebugConfig.authGated) {
      DebugLogger.debug(
        'Auth: Starting Google Sign-In (Raw Console Check)',
        category: 'AUTH',
      );
    }
    DebugLogger.info('Auth: Starting Google Sign-In', category: 'AUTH');

    try {
      String? idToken;

      final isDesktop =
          !kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

      if (isDesktop) {
        // Use custom Desktop implementation
        if (DebugConfig.authGated) {
          DebugLogger.debug('Auth: Using DesktopGoogleAuth', category: 'AUTH');
        }
        idToken = await DesktopGoogleAuth.signIn();
        // DesktopAuth doesn't return email automatically in our simplified flow,
        // but the backend will extract it from the token.
        // We can decode it here if needed for UI, but let's rely on backend verification response.
      } else {
        // Use standard plugin for Mobile/Web (v7.x API)
        // Ensure the singleton is initialized
        if (DebugConfig.authGated) {
          DebugLogger.debug(
            'Auth: Using Standard GoogleSignIn',
            category: 'AUTH',
          );
        }
        await GoogleSignIn.instance.initialize();

        try {
          final account = await GoogleSignIn.instance.authenticate(
            scopeHint: ['email', 'profile'],
          );

          final auth = account.authentication;
          idToken = auth.idToken;
        } catch (error) {
          debugPrint('Google Sign-In error: $error');
          setState(() => _message = 'Sign-in cancelled or failed.');
          return;
        }
      }

      if (idToken == null) {
        setState(() => _message = 'Sign-in cancelled or failed.');
        return;
      }

      // Get Gardener ID for auto-linking
      final gardenerId = ref.read(p2pManagerProvider).gardenerId;

      // Send to backend for verification
      final response = await HttpLogger.post(
        Uri.parse('$_apiBase/api/auth/google/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          if (gardenerId != null) 'gardenerId': gardenerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;

        if (token != null) {
          // Store token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          // Extract user info from Backend Response (Session User Object)
          if (data['user'] != null) {
            final userId = data['user']['id'];
            final userEmail = data['user']['email'];

            if (userId != null) {
              await prefs.setString('user_id', userId);
            }
            if (userEmail != null) {
              await prefs.setString('user_email', userEmail);
            }
          }

          // Handle Auto-Linking Secret
          if (data['secret'] != null) {
            final secret = data['secret'] as String;
            final security = SecurityManager();
            await security.setSharedSecret(secret);
            debugPrint('Auth: Auto-linked device successfully.');
          }

          unawaited(HapticManager.success());
          widget.onAuthenticated();
        } else {
          setState(() => _message = 'Authentication failed.');
        }
      } else {
        String errorMsg = 'Backend verification failed.';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) {
            errorMsg = data['error'];
          }
        } catch (_) {}
        setState(() => _message = '$errorMsg (${response.statusCode})');
      }
    } catch (error) {
      if (DebugConfig.authGated) {
        DebugLogger.error(
          'Auth: [Error] Sign in failed: $error',
          category: 'AUTH',
        );
      }
      setState(() {
        _message = 'Sign in failed: $error';
        _isLoading = false;
      });
      DebugLogger.error('Auth Error', error: error, category: 'AUTH');
    }
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

                          // Google Sign-In button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, _, _) =>
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
                            onPressed: () {
                              DebugLogger.info(
                                'Auth: Resetting Magic Link form',
                                category: 'UI',
                              );
                              setState(() => _magicLinkSent = false);
                            },
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

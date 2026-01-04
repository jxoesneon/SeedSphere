import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium glassmorphic dialog for user profile management.
///
/// Displays current user identity (email/ID) and provides logout functionality.
class UserProfileDialog extends StatefulWidget {
  /// Creates a [UserProfileDialog].
  const UserProfileDialog({super.key});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  String? _userId;
  String? _userEmail;
  bool _isUnlinking = false;

  String get _apiBase {
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
      return 'http://localhost:8080';
    }
    return 'https://seedsphere.fly.dev';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id') ?? 'Unknown ID';
      _userEmail = prefs.getString('user_email') ?? 'Unknown Email';
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');

    if (context.mounted) {
      // Pop the dialog
      Navigator.pop(context);
      // Pop the SwarmDashboard to return to HomeScreen (which will then show AuthScreen if triggered)
      Navigator.pop(context);
    }
  }

  Future<void> _unlinkAllDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AethericTheme.deepVoid,
        title: const Text(
          'UNLINK ALL DEVICES?',
          style: TextStyle(color: Colors.white, letterSpacing: 2),
        ),
        content: const Text(
          'This will sign out all your devices. You will need to sign back in everywhere.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'UNLINK ALL',
              style: TextStyle(color: AethericTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUnlinking = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('$_apiBase/api/auth/unlink'),
        headers: {
          'Content-Type': 'application/json',
          'x-seedsphere-client': 'gardener-v1', // CSRF Protection
          if (token != null) 'cookie': 'seedsphere_session=$token',
        },
      );

      if (response.statusCode == 200) {
        // Success - log out this session too as it's now invalid
        if (mounted) await _logout(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unlink devices.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUnlinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: AethericGlass(
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_circle_rounded,
              size: 64,
              color: AethericTheme.aetherBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'USER PROFILE',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoRow('EMAIL', _userEmail ?? 'Loading...'),
            const SizedBox(height: 20),
            _buildInfoRow('ID', _userId ?? 'Loading...'),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(color: Colors.white54, letterSpacing: 1.2),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isUnlinking ? null : _unlinkAllDevices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    _isUnlinking ? 'UNLINKING...' : 'UNLINK ALL',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AethericTheme.error.withValues(alpha: 0.1),
                    foregroundColor: AethericTheme.error,
                    side: const BorderSide(
                      color: AethericTheme.error,
                      width: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'LOGOUT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }
}

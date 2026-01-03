import 'package:flutter/material.dart';
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

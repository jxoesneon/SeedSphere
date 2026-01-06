import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized navigation card that leads to another screen.
///
/// Following the Gardener Design System specification:
/// - AethericGlass container
/// - ListTile layout with icon, title, subtitle
/// - Trailing arrow indicator
/// - Tap to navigate
class NavigationCard extends StatelessWidget {
  /// Leading icon
  final IconData icon;

  /// Card title
  final String title;

  /// Card description
  final String description;

  /// Navigation callback
  final VoidCallback onTap;

  /// Optional badge text (e.g., "3 configured")
  final String? badge;

  const NavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $description',
      hint: 'Tap to open',
      child: AethericGlass(
        child: ListTile(
          leading: Icon(icon, color: AethericTheme.aetherBlue),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AethericTheme.aetherBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.outfit(
                      color: AethericTheme.aetherBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            description,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white30,
            size: 16,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized section header for all settings pages.
///
/// Following the Gardener Design System specification:
/// - 12sp Outfit font
/// - Bold weight
/// - 1.5 letter spacing
/// - Aether Blue color
/// - Always UPPERCASE
///
/// Used to separate major setting groups within a page.
class SectionHeader extends StatelessWidget {
  /// The section title text (will be converted to uppercase)
  final String title;

  /// Optional icon to display before the title
  final IconData? icon;

  const SectionHeader(this.title, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AethericTheme.aetherBlue),
          const SizedBox(width: 8),
        ],
        Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            color: AethericTheme.aetherBlue,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

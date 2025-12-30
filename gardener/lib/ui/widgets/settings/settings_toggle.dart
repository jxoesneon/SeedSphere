import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized toggle switch for boolean settings.
///
/// Following the Gardener Design System specification:
/// - AethericGlass container
/// - SwitchListTile with consistent styling
/// - Optional leading icon
/// - Semantic colors (standard blue, warning orange)
/// - Built-in accessibility
class SettingsToggle extends StatelessWidget {
  /// The primary label for this setting
  final String title;

  /// Description text shown below the title
  final String description;

  /// Current toggle value
  final bool value;

  /// Callback when value changes
  final ValueChanged<bool> onChanged;

  /// Optional leading icon
  final IconData? leadingIcon;

  /// Whether this is a warning-level setting (uses orange accent)
  final bool isWarning;

  /// Optional trailing widget (e.g., badge, indicator)
  final Widget? trailing;

  const SettingsToggle({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.leadingIcon,
    this.isWarning = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isWarning ? Colors.orange : AethericTheme.aetherBlue;
    final trackColor = isWarning
        ? Colors.orange.withValues(alpha: 0.5)
        : AethericTheme.aetherBlue;
    final thumbColor = isWarning ? Colors.orange : null;

    return Semantics(
      toggled: value,
      label: title,
      hint: description,
      child: AethericGlass(
        child: SwitchListTile(
          secondary:
              leadingIcon != null ? Icon(leadingIcon, color: iconColor) : null,
          title: Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            description,
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          value: value,
          activeTrackColor: trackColor,
          activeThumbColor: thumbColor,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

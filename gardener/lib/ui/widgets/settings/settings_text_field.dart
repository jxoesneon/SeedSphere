import 'package:flutter/material.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized text input field for settings.
///
/// Following the Gardener Design System specification:
/// - AethericGlass container
/// - Optional leading icon
/// - Optional trailing action
/// - Obscure text support
/// - Validation states
class SettingsTextField extends StatelessWidget {
  /// Text editing controller
  final TextEditingController controller;

  /// Label text
  final String label;

  /// Optional hint text
  final String? hint;

  /// Optional leading icon
  final IconData? leadingIcon;

  /// Optional trailing widget (e.g., paste button)
  final Widget? trailing;

  /// Whether to obscure text (for passwords/API keys)
  final bool obscureText;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Maximum number of lines (null for single line)
  final int? maxLines;

  /// Whether the field is enabled
  final bool enabled;

  const SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.leadingIcon,
    this.trailing,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: label,
      hint: hint,
      child: AethericGlass(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            enabled: enabled,
            maxLines: obscureText ? 1 : maxLines,
            onChanged: onChanged,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 13,
              ),
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 13,
              ),
              border: InputBorder.none,
              icon: leadingIcon != null
                  ? Icon(
                      leadingIcon,
                      color: Colors.white54,
                      size: 20,
                    )
                  : null,
              suffixIcon: trailing,
            ),
          ),
        ),
      ),
    );
  }
}

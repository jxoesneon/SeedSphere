import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized dropdown selector for settings.
///
/// Following the Gardener Design System specification:
/// - AethericGlass container
/// - Consistent dropdown styling
/// - Icon integration
/// - Semantic labeling
class SettingsDropdown<T> extends StatelessWidget {
  /// Current selected value
  final T value;

  /// List of available options
  final List<T> items;

  /// Callback when selection changes
  final ValueChanged<T?> onChanged;

  /// Icon displayed on the right side
  final IconData icon;

  /// Function to get display text for each item
  final String Function(T) getLabel;

  /// Optional hint text shown when no value selected
  final String? hint;

  const SettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.getLabel,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return AethericGlass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            dropdownColor: const Color(0xFF1E293B),
            value: value,
            isExpanded: true,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
            ),
            icon: Icon(icon, color: AethericTheme.aetherBlue),
            hint: hint != null
                ? Text(
                    hint!,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  )
                : null,
            items: items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(getLabel(item)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

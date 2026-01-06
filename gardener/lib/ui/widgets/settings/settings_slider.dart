import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized slider with labels for numeric settings.
///
/// Following the Gardener Design System specification:
/// - AethericGlass container
/// - Labels above slider showing current value
/// - Consistent styling
/// - Accessibility support
class SettingsSlider extends StatelessWidget {
  /// Current slider value
  final double value;

  /// Minimum value
  final double min;

  /// Maximum value
  final double max;

  /// Number of divisions (null for continuous)
  final int? divisions;

  /// Callback when value changes
  final ValueChanged<double> onChanged;

  /// Label prefix (e.g., "Quality Level")
  final String label;

  /// Optional value formatter (defaults to showing integer)
  final String Function(double)? valueFormatter;

  /// Optional labels for discrete values
  /// Map of value -> label text
  final Map<double, String>? discreteLabels;

  const SettingsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    this.divisions,
    this.valueFormatter,
    this.discreteLabels,
  });

  String get _formattedValue {
    if (valueFormatter != null) {
      return valueFormatter!(value);
    }
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: '$label: $_formattedValue',
      child: AethericGlass(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row
              discreteLabels != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: discreteLabels!.entries.map((entry) {
                        final isActive = (value - entry.key).abs() < 0.01;
                        return Text(
                          entry.value,
                          style: GoogleFonts.outfit(
                            color: isActive ? Colors.white : Colors.white38,
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    )
                  : Text(
                      '$label: $_formattedValue',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

              // Slider
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                thumbColor: AethericTheme.aetherBlue,
                activeColor: AethericTheme.aetherBlue,
                inactiveColor: Colors.white10,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

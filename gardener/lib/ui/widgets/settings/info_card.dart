import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Severity level for informational cards
enum InfoCardSeverity {
  /// Informational message (blue)
  info,

  /// Success message (green)
  success,

  /// Warning message (amber)
  warning,

  /// Error message (red)
  error,
}

/// Standardized informational card for alerts and notices.
///
/// Following the Gardener Design System specification:
/// - 12dp padding
/// - Colored background and border based on severity
/// - Icon + message layout
/// - Semantic color system
class InfoCard extends StatelessWidget {
  /// The message to display
  final String message;

  /// Severity level (determines color and icon)
  final InfoCardSeverity severity;

  /// Optional custom icon (overrides default severity icon)
  final IconData? customIcon;

  /// Optional action button
  final Widget? action;

  const InfoCard({
    super.key,
    required this.message,
    this.severity = InfoCardSeverity.info,
    this.customIcon,
    this.action,
  });

  /// Get the semantic color for this severity
  Color get _color {
    switch (severity) {
      case InfoCardSeverity.info:
        return const Color(0xFF3B82F6); // Blue
      case InfoCardSeverity.success:
        return const Color(0xFF10B981); // Green
      case InfoCardSeverity.warning:
        return const Color(0xFFF59E0B); // Amber
      case InfoCardSeverity.error:
        return const Color(0xFFEF4444); // Red
    }
  }

  /// Get the default icon for this severity
  IconData get _defaultIcon {
    switch (severity) {
      case InfoCardSeverity.info:
        return Icons.info_outline_rounded;
      case InfoCardSeverity.success:
        return Icons.check_circle_outline_rounded;
      case InfoCardSeverity.warning:
        return Icons.warning_amber_rounded;
      case InfoCardSeverity.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: _severityLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(customIcon ?? _defaultIcon, color: _color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _severityLabel {
    switch (severity) {
      case InfoCardSeverity.info:
        return 'Information: $message';
      case InfoCardSeverity.success:
        return 'Success: $message';
      case InfoCardSeverity.warning:
        return 'Warning: $message';
      case InfoCardSeverity.error:
        return 'Error: $message';
    }
  }
}

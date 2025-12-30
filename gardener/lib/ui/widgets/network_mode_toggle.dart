import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Network configuration mode selection.
enum NetworkMode {
  /// Automatic configuration with smart defaults (recommended)
  automatic,

  /// Manual configuration for advanced users
  manual,
}

/// A mode selector for choosing between automatic and manual network configuration.
///
/// Features:
/// - Segmented button design (Material 3)
/// - Tooltip explanations for each mode
/// - Clear visual distinction between active/inactive states
/// - Accessibility support
///
/// Following 2025 UX principles:
/// - Smart defaults (Auto recommended)
/// - Progressive disclosure (manual reveals advanced settings)
/// - Clear benefit communication
class NetworkModeToggle extends StatelessWidget {
  /// Current selected mode
  final NetworkMode mode;

  /// Callback when mode changes
  final ValueChanged<NetworkMode> onModeChanged;

  const NetworkModeToggle({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AethericTheme.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            'NETWORK MODE',
            style: GoogleFonts.outfit(
              color: AethericTheme.aetherBlue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Segmented button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    key: const Key('network_mode_automatic'),
                    label: 'Automatic',
                    isSelected: mode == NetworkMode.automatic,
                    icon: Icons.auto_awesome_rounded,
                    onTap: () => onModeChanged(NetworkMode.automatic),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ModeButton(
                    key: const Key('network_mode_manual'),
                    label: 'Manual',
                    isSelected: mode == NetworkMode.manual,
                    icon: Icons.tune_rounded,
                    onTap: () => onModeChanged(NetworkMode.manual),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mode == NetworkMode.automatic
                      ? 'Auto mode optimizes settings based on your connection'
                      : 'Manual mode gives you full control over network parameters',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual mode button within the segmented control
class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label mode',
      selected: isSelected,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AethericTheme.aetherBlue.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AethericTheme.aetherBlue
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AethericTheme.aetherBlue : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';

/// A wrapper widget that provides a visual focus "aura" for TV and Gamepad navigation.
///
/// Specifically designed for directional pad (D-Pad) navigation on Android TV,
/// Apple TV, or Gamepads. When the widget gains focus, it displays a glowing
/// shadow around the child with a smooth animation.
///
/// **Features:**
/// - Integrates with Flutter's [Focus] system.
/// - Uses [AnimatedContainer] for smooth aura transitions.
/// - Matches the [AethericTheme.aetherBlue] brand color for the glow.
///
/// Example:
/// ```dart
/// DpadFocusAura(
///   onTap: () => print('Selected!'),
///   child: Card(child: Text('TV Option')),
/// )
/// ```
class DpadFocusAura extends StatefulWidget {
  /// The widget that should receive the focus aura.
  final Widget child;

  /// Optional callback triggered when the widget is tapped or selected.
  final VoidCallback? onTap;

  /// Creates a [DpadFocusAura] instance.
  const DpadFocusAura({super.key, required this.child, this.onTap});

  @override
  State<DpadFocusAura> createState() => _DpadFocusAuraState();
}

class _DpadFocusAuraState extends State<DpadFocusAura> {
  /// Internal state tracking whether the widget currently holds focus.
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Track focus state changes from D-Pad navigation
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Apply the glow effect only when focused
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AethericTheme.aetherBlue.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

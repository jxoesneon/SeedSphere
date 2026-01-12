import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// A compact, horizontally-laid-out settings card following 2025 UI/UX best practices.
///
/// Features:
/// - 72dp height for better information density
/// - Horizontal layout (icon | title + subtitle | trailing)
/// - Optional status badge
/// - Micro-interactions and animations
/// - WCAG 2.2 compliant accessibility
class CompactSettingsCard extends StatefulWidget {
  /// The title of the settings category
  final String title;

  /// The icon to display
  final IconData icon;

  /// Description text shown below the title
  final String description;

  /// Optional status badge text (e.g., "Connected", "3 trackers")
  final String? statusBadge;

  /// Badge color (defaults to aetherBlue)
  final Color? badgeColor;

  /// Optional hero tag for transitions
  final String? heroTag;

  /// Optional trailing widget for complex live metrics
  final Widget? trailing;

  /// Priority level affects visual styling
  /// - critical: Primary accent (Swarm Uplink, Key Vault)
  /// - standard: Secondary color (Cortex, Playback)
  /// - optional: Tertiary color (Providers)
  final SettingsPriority priority;

  /// Callback when card is tapped
  final VoidCallback onTap;

  const CompactSettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
    this.statusBadge,
    this.badgeColor,
    this.heroTag,
    this.trailing,
    this.priority = SettingsPriority.standard,
  });

  @override
  State<CompactSettingsCard> createState() => _CompactSettingsCardState();
}

class _CompactSettingsCardState extends State<CompactSettingsCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _iconColor {
    switch (widget.priority) {
      case SettingsPriority.critical:
        return AethericTheme.aetherBlue;
      case SettingsPriority.standard:
        return Colors.white70;
      case SettingsPriority.optional:
        return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title} settings',
      hint: widget.description,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AethericTheme.glassBorder, width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _animationController.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _animationController.reverse();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _animationController.reverse();
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: AethericTheme.aetherBlue.withValues(alpha: 0.1),
              highlightColor: AethericTheme.aetherBlue.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Leading icon (24dp)
                    widget.heroTag != null
                        ? Hero(tag: widget.heroTag!, child: _buildIcon())
                        : _buildIcon(),
                    const SizedBox(width: 16),

                    // Title and description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Optional status badge + trailing + chevron
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.trailing != null) ...[
                          widget.trailing!,
                          const SizedBox(width: 8),
                        ],
                        if (widget.statusBadge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (widget.badgeColor ??
                                          AethericTheme.aetherBlue)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (widget.badgeColor ??
                                            AethericTheme.aetherBlue)
                                        .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.statusBadge!,
                              style: GoogleFonts.outfit(
                                color:
                                    widget.badgeColor ??
                                    AethericTheme.aetherBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: _iconColor,
        end: _isPressed ? AethericTheme.aetherBlue : _iconColor,
      ),
      duration: const Duration(milliseconds: 200),
      builder: (context, color, child) {
        return Icon(widget.icon, size: 24, color: color);
      },
    );
  }
}

/// Priority level for settings categories
enum SettingsPriority {
  /// Critical settings (Swarm Uplink, Key Vault)
  critical,

  /// Standard settings (Cortex, Playback)
  standard,

  /// Optional settings (Providers)
  optional,
}

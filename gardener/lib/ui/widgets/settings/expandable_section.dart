import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standardized expandable section for progressive disclosure.
///
/// Following the Gardener Design System specification:
/// - Collapsible container with header
/// - Summary shown when collapsed
/// - Smooth expand/collapse animation
/// - Optional badge count
///
/// Based on the pattern from Swarm Uplink Settings.
class ExpandableSection extends StatefulWidget {
  /// Section title
  final String title;

  /// Icon displayed in header
  final IconData icon;

  /// Summary text shown when collapsed
  final String? collapsedSummary;

  /// Content shown when expanded
  final Widget child;

  /// Whether section starts expanded
  final bool initiallyExpanded;

  /// Optional badge text (e.g., "3 active")
  final String? badge;

  const ExpandableSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.collapsedSummary,
    this.initiallyExpanded = false,
    this.badge,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.title,
      hint: _isExpanded
          ? 'Expanded, tap to collapse'
          : 'Collapsed, tap to expand',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.01),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AethericTheme.glassBorder,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        color: AethericTheme.aetherBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.title.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: AethericTheme.aetherBlue,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.3,
                                    fontSize: 12,
                                  ),
                                ),
                                if (widget.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AethericTheme.aetherBlue
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.badge!,
                                      style: GoogleFonts.outfit(
                                        color: AethericTheme.aetherBlue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (!_isExpanded &&
                                widget.collapsedSummary != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.collapsedSummary!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expandable content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: widget.child,
                  ),
                ],
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}

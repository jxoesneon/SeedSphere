import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum ScraperStatus { idle, searching, done, error }

class ScraperState {
  final String name;
  final ScraperStatus status;
  final int yieldCount;
  final DateTime lastUpdated;

  ScraperState({
    required this.name,
    this.status = ScraperStatus.idle,
    this.yieldCount = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  ScraperState copyWith({
    ScraperStatus? status,
    int? yieldCount,
    DateTime? lastUpdated,
  }) {
    return ScraperState(
      name: name,
      status: status ?? this.status,
      yieldCount: yieldCount ?? this.yieldCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ScraperSpectrum extends StatelessWidget {
  final List<ScraperState> scrapers;

  const ScraperSpectrum({super.key, required this.scrapers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEURAL RESONANCE',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${scrapers.where((s) => s.status == ScraperStatus.done).length} / ${scrapers.length} ACTIVE',
                style: GoogleFonts.firaCode(
                  color: AethericTheme.kryptonGreen,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: scrapers.map((s) => _buildBar(s)).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Legend / Axis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: scrapers.map((s) => _buildLabel(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(ScraperState state) {
    // Determine height based on yield or status
    double heightPercentage;
    Color color;
    bool pulsing = false;

    switch (state.status) {
      case ScraperStatus.searching:
        heightPercentage = 0.4; // Searching baseline
        color = Colors.white;
        pulsing = true;
        break;
      case ScraperStatus.done:
        // Log scale for yield: 0 -> 10%, 10 -> 50%, 100 -> 100%
        final safeYield = state.yieldCount.clamp(0, 100);
        heightPercentage = 0.1 + (safeYield / 100.0) * 0.9;
        color = AethericTheme.kryptonGreen;
        break;
      case ScraperStatus.error:
        heightPercentage = 0.2;
        color = Colors.redAccent;
        break;
      default: // Covers idle and error fallbacks implicitly if needed
        heightPercentage = 0.05; // Dim baseline
        color = Colors.white12;
        break;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (state.status == ScraperStatus.done)
              Text(
                '${state.yieldCount}',
                style: GoogleFonts.firaCode(color: Colors.white70, fontSize: 8),
              ),
            const SizedBox(height: 2),
            _AnimatedBar(
              heightPercentage: heightPercentage,
              color: color,
              pulsing: pulsing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(ScraperState state) {
    // Abbreviate name: "Torrentio" -> "TR", "YTS" -> "YT"
    final label = state.name.length > 2
        ? state.name.substring(0, 2).toUpperCase()
        : state.name.toUpperCase();

    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.firaCode(
            color: state.status == ScraperStatus.idle
                ? Colors.white24
                : Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  final double heightPercentage;
  final Color color;
  final bool pulsing;

  const _AnimatedBar({
    required this.heightPercentage,
    required this.color,
    required this.pulsing,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      height: 80 * widget.heightPercentage, // Fixed max height reference of 80
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: widget.color.withValues(alpha: widget.pulsing ? 0.8 : 1.0),
        boxShadow: widget.pulsing || widget.heightPercentage > 0.5
            ? [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
              ]
            : [],
      ),
      child: widget.pulsing
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        widget.color.withValues(alpha: 0.3),
                        widget.color.withValues(
                          alpha: 0.3 + (_controller.value * 0.7),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';

class SwarmHealthHero extends StatefulWidget {
  final int peerCount;
  final bool isHealthy;

  const SwarmHealthHero({
    super.key,
    required this.peerCount,
    this.isHealthy = true,
  });

  @override
  State<SwarmHealthHero> createState() => _SwarmHealthHeroState();
}

class _SwarmHealthHeroState extends State<SwarmHealthHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Pulse Background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _PulsePainter(
                  animationValue: _controller.value,
                  color: widget.isHealthy
                      ? AethericTheme.success
                      : AethericTheme.warning,
                ),
                size: const Size(double.infinity, 240),
              );
            },
          ),

          // Glass Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AethericGlass(
              borderRadius: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isHealthy
                          ? Icons.wifi_tethering
                          : Icons.wifi_tethering_off,
                      size: 48,
                      color: widget.isHealthy
                          ? AethericTheme.success
                          : AethericTheme.warning,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isHealthy ? 'SYSTEM OPTIMAL' : 'SYSTEM DEGRADED',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CONNECTED TO ${widget.peerCount} ACTIVE PEERS',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _PulsePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.height * 0.8;

    // Draw multiple ripples
    for (int i = 0; i < 3; i++) {
      final opacity =
          (1.0 - ((animationValue + i * 0.33) % 1.0)).clamp(0.0, 1.0);
      final radius = ((animationValue + i * 0.33) % 1.0) * maxRadius;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => true;
}

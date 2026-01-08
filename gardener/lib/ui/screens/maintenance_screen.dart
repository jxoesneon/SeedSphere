import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'dart:math' as math;

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AethericTheme.deepVoid,
      body: Stack(
        children: [
          // Background ambient glow
          Positioned.fill(child: CustomPaint(painter: _AmbientGlowPainter())),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    math.sin(_controller.value * 2 * math.pi) * 10,
                  ),
                  child: child,
                );
              },
              child: AethericGlass(
                borderRadius: 24,
                baseColor: AethericTheme.crystalline,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48.0,
                    vertical: 64.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rotating Gear/Wrench Icon Container
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AethericTheme.aetherBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.settings_outlined,
                            size: 80,
                            color: AethericTheme.aetherBlue.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          Icon(
                            Icons.handyman_outlined,
                            size: 40,
                            color: AethericTheme.warning.withValues(alpha: 0.9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      // Main Text
                      Text(
                        'SYSTEM UNDER\nMAINTENANCE',
                        textAlign: TextAlign.center,
                        style: AethericTheme.darkTheme.textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 32,
                              letterSpacing: 1.5,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: AethericTheme.aetherBlue.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle background nebula effect
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          AethericTheme.aetherBlue.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final Paint paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 1.2,
        colors: [
          AethericTheme.warning.withValues(alpha: 0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

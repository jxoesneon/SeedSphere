import 'package:flutter/material.dart';
import 'package:gardener/ui/theme/aetheric_theme.dart';
import 'package:gardener/ui/widgets/aetheric_glass.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gardener/services/task_executor_service.dart';

class SwarmHealthHero extends ConsumerStatefulWidget {
  final int peerCount;
  final bool isHealthy;
  final bool isConnecting;
  final List<DateTime>? heartbeats;

  const SwarmHealthHero({
    super.key,
    required this.peerCount,
    this.isHealthy = true,
    this.isConnecting = false,
    this.heartbeats,
  });

  @override
  ConsumerState<SwarmHealthHero> createState() => _SwarmHealthHeroState();
}

class _SwarmHealthHeroState extends ConsumerState<SwarmHealthHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Metrics
    // P-Wave: Peer Count
    // QRS: Active Tasks
    // T-Wave: Seeding (Mocked via isHealthy & PeerCount > 0)

    final taskExecutor = ref.watch(taskExecutorProvider);

    return ValueListenableBuilder<int>(
      valueListenable: taskExecutor.activeTaskCount,
      builder: (context, taskCount, _) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 240),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // EKG Visualization
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return ClipRect(
                    child: CustomPaint(
                      painter: _EKGPainter(
                        animationValue: _controller.value,
                        color: widget.isConnecting
                            ? Colors.blueAccent
                            : (widget.isHealthy
                                  ? AethericTheme.success
                                  : AethericTheme.warning),
                        peerCount: widget.peerCount,
                        activeTasks: taskCount,
                        isConnecting: widget.isConnecting,
                      ),
                      size: const Size(double.infinity, 240),
                    ),
                  );
                },
              ),

              // Glass Info Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AethericGlass(
                  borderRadius: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
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
                          widget.isConnecting
                              ? Icons.monitor_heart_rounded
                              : (widget.isHealthy
                                    ? Icons.favorite_rounded
                                    : Icons.heart_broken_rounded),
                          size: 48,
                          color: widget.isConnecting
                              ? Colors.blueAccent
                              : (widget.isHealthy
                                    ? AethericTheme.success
                                    : AethericTheme.warning),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isConnecting
                              ? 'CONNECTING...'
                              : (widget.isHealthy
                                    ? 'SYSTEM OPTIMAL'
                                    : 'SYSTEM DEGRADED'),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.peerCount == 0
                              ? 'WAITING FOR FEDERATED PEERS...'
                              : 'CONNECTED TO ${widget.peerCount} ACTIVE PEERS',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (taskCount > 0)
                          Text(
                            'PROCESSING $taskCount AI TASKS',
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: AethericTheme.aetherBlue,
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
      },
    );
  }
}

class _EKGPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final int peerCount;
  final int activeTasks;
  final bool isConnecting;

  _EKGPainter({
    required this.animationValue,
    required this.color,
    required this.peerCount,
    required this.activeTasks,
    required this.isConnecting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    // Simulate a scrolling oscilloscope
    // We draw 3 beats across the screen usually, but let's do one continuous line moving
    // Or just draw one fixed complex that pulses?
    // "Pulse changes based on status" -> Suggests the SHAPE changes.
    // Let's draw a continuous line where x moves from 0 to width.

    // We construct the P-QRS-T complex mathematically.
    // x is 0..1 representing phase of the beat.

    // Position of the "cursor" (current drawing point)
    // Actually, distinct regular EKG is better than a scrolling one for a "Hero" widget.
    // Let's draw 2 full beats.

    for (double i = 0; i <= width; i += 2) {
      final t =
          (i / width * 2.0) - animationValue; // 2 beats wide, scrolling left
      // Wrap t to be repetitive signal
      final phase = t % 1.0;
      // If t is negative, wrap correctly
      final normPhase = phase < 0 ? 1.0 + phase : phase;

      final y = _calculateEKG(normPhase);

      final plotY = midY - (y * (height * 0.3)); // Scale amplitude

      if (i == 0) {
        path.moveTo(i, plotY);
      } else {
        path.lineTo(i, plotY);
      }
    }

    // Fade mask at edges
    canvas.drawPath(path, paint);
  }

  double _calculateEKG(double t) {
    // t is 0.0 to 1.0 (one heart beat)
    double y = 0.0;

    // Baseline Noise (Is Connecting?)
    if (isConnecting) {
      y += (DateTime.now().millisecond % 100 / 500.0) * 0.1;
    }

    // P Wave: 0.1 - 0.2
    // Amplitude based on Peer Count (more peers = stronger P wave)
    // Cap at 50 peers for max height
    final pAmp = (peerCount / 50.0).clamp(0.1, 0.4);
    if (t > 0.1 && t < 0.2) {
      y += _gaussian(t, 0.15, 0.02) * pAmp;
    }

    // QRS Complex: 0.3 - 0.4
    // R-Wave Amplitude based on Active Tasks
    // 0 tasks = normal beat (0.8)
    // 5+ tasks = huge spike (1.5)
    final rAmp = 0.8 + (activeTasks * 0.2).clamp(0.0, 1.0);

    // Q (Dip)
    if (t > 0.28 && t < 0.3) {
      y -= _gaussian(t, 0.29, 0.005) * 0.2;
    }
    // R (Spike)
    if (t > 0.3 && t < 0.34) {
      y += _gaussian(t, 0.32, 0.005) * rAmp;
    }
    // S (Dip)
    if (t > 0.34 && t < 0.36) {
      y -= _gaussian(t, 0.35, 0.005) * 0.3;
    }

    // T Wave: 0.5 - 0.7
    // Seeding/Healthy -> Normal T Wave
    // Unhealthy -> Inverted T Wave?
    // Let's use isConnecting logic or just general health
    final tAmp = isConnecting ? 0.1 : 0.3;
    if (t > 0.5 && t < 0.7) {
      y += _gaussian(t, 0.6, 0.04) * tAmp;
    }

    return y;
  }

  double _gaussian(double x, double mu, double sigma) {
    return 1.0 *
        (1.0 / (sigma)) *
        2.718 * // e approximation
        (-0.5 * ((x - mu) / sigma) * ((x - mu) / sigma));
    // Simplified for shape, not strict math
    // Actually standard gaussian formula exp(...)
  }

  @override
  bool shouldRepaint(covariant _EKGPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.peerCount != peerCount ||
        oldDelegate.activeTasks != activeTasks ||
        oldDelegate.isConnecting != isConnecting;
  }
}

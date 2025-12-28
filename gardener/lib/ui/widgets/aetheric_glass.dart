import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

/// A premium glassmorphic container with optional shader support.
///
/// Provides the signature "Crystalline" look of the SeedSphere app. It features
/// background blurring, a translucent base color, and subtle borders.
///
/// **Platform Adaptation:**
/// - **Mobile (Android/iOS)**: Attempts to use a custom fragment shader
///   (`aetheric_glass.frag`) for high-performance, complex glass effects.
/// - **Web/Desktop**: Falls back to [BackdropFilter] with [ImageFilter.blur],
///   as shader support varies or is less optimized on these targets.
///
/// Example:
/// ```dart
/// AethericGlass(
///   borderRadius: 20,
///   child: Text('Glassmorphic Content'),
/// )
/// ```
class AethericGlass extends StatefulWidget {
  /// The widget to be contained within the glass container.
  final Widget child;

  /// The corner radius for the container and its effects.
  final double borderRadius;

  /// The base translucent color applied to the glass.
  final Color baseColor;

  /// Global toggle to force the use of the [BackdropFilter] fallback.
  /// Primarily used for testing or debugging performance issues.
  static bool useFallback = false;

  /// Creates an [AethericGlass] instance.
  const AethericGlass({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.baseColor = const Color(0x1AFFFFFF),
  });

  @override
  State<AethericGlass> createState() => _AethericGlassState();
}

class _AethericGlassState extends State<AethericGlass> {
  @override
  Widget build(BuildContext context) {
    // Determine if we should use the standard Flutter backdrop filter fallback
    final bool isDesktopOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (AethericGlass.useFallback || isDesktopOrWeb) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          color: widget.baseColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      );
    }

    // Advanced shader-based rendering for mobile platforms
    // coverage:ignore-start
    return ShaderBuilder(
      (context, shader, child) {
        return CustomPaint(
          painter: GlassPainter(
            shader: shader,
            baseColor: widget.baseColor,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: widget.child,
          ),
        );
      },
      assetKey: 'assets/shaders/aetheric_glass.frag',
      child: widget.child,
    );
    // coverage:ignore-end
  }
}

/// Custom painter that applies a fragment shader to a rectangular area.
/// Used for advanced mobile glass effects.
class GlassPainter extends CustomPainter {
  /// The compiled fragment shader to use for rendering.
  final FragmentShader shader;

  /// The base color and opacity to pass to the shader.
  final Color baseColor;

  /// Creates a [GlassPainter] instance.
  GlassPainter({required this.shader, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Pass uniforms to the GLSL shader
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, DateTime.now().millisecondsSinceEpoch / 1000.0);
    shader.setFloat(3, baseColor.r);
    shader.setFloat(4, baseColor.g);
    shader.setFloat(5, baseColor.b);
    shader.setFloat(6, baseColor.a);

    final Paint paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

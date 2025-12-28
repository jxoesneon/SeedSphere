import 'package:flutter/material.dart';

/// Defines the spring physics constants used for fluid UI transitions.
///
/// SeedSphere uses physics-based animations to create a high-end, responsive
/// feel that mimics biological or natural movement.
class EntropySpring {
  /// A standard spring configuration with balanced mass, stiffness, and damping.
  static const SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 12.0,
  );

  /// Creates a standard [AnimationController] with a default 800ms duration.
  ///
  /// [vsync] - The [TickerProvider] (usually a [State] with [TickerProviderStateMixin]).
  static AnimationController createController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );
  }
}

/// A wrapper widget that applies a physics-based entrance scale animation.
///
/// When first inserted into the widget tree, [child] will scale up from 90%
/// to 100% using an elastic (springy) curve.
///
/// Example:
/// ```dart
/// SpringScaleTransition(
///   child: Card(child: Text('Hello')),
/// )
/// ```
class SpringScaleTransition extends StatefulWidget {
  /// The widget to be animated.
  final Widget child;

  /// Creates a [SpringScaleTransition] instance.
  const SpringScaleTransition({super.key, required this.child});

  @override
  State<SpringScaleTransition> createState() => _SpringScaleTransitionState();
}

class _SpringScaleTransitionState extends State<SpringScaleTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut, // Elastic curve simulates spring physics
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

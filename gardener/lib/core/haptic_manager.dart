import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Platform-specific haptic feedback manager.
///
/// Provides tactile feedback for user interactions on mobile devices.
/// Automatically handles platform detection and gracefully degrades
/// on unsupported platforms (web, desktop).
///
/// **Intensity levels:**
/// - **Light**: Subtle feedback for UI transitions
/// - **Medium**: Standard feedback for button taps
/// - **Heavy**: Strong feedback for important actions
/// - **Success**: Feedback for completed operations
///
/// Example:
/// ```dart
/// // Button tap
/// await HapticManager.medium();
///
/// // Important action
/// await HapticManager.heavy();
///
/// // Operation completed
/// await HapticManager.success();
/// ```
class HapticManager {
  /// Triggers light haptic feedback.
  ///
  /// Suitable for subtle UI transitions like page swipes or list scrolling.
  /// Only activates on Android and iOS devices.
  static Future<void> light() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await HapticFeedback.lightImpact();
    }
    // Desktop/TV: Could trigger visual ripple or audio cue
  }

  /// Triggers medium haptic feedback.
  ///
  /// Suitable for standard interactions like button taps or toggles.
  /// Only activates on Android and iOS devices.
  static Future<void> medium() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Triggers heavy haptic feedback.
  ///
  /// Suitable for important actions like deletions or confirmations.
  /// Only activates on Android and iOS devices.
  static Future<void> heavy() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Triggers success/completion haptic feedback.
  ///
  /// Suitable for confirming successful operations (e.g., file downloaded,
  /// stream started). Only activates on Android and iOS devices.
  static Future<void> success() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await HapticFeedback.vibrate();
    }
  }
}

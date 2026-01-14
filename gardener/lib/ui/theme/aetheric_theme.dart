import 'package:flutter/material.dart';

/// The core design system and theme definition for SeedSphere.
///
/// Implements the "Aetheric" design language, characterized by deep space
/// colors (Deep Void), vibrant cyan accents (Aether Blue), and pervasive
/// glassmorphism (Crystalline).
///
/// **Design Principles:**
/// - **Depth**: Use of gradients and layers to simulate a cosmic environment.
/// - **Clarity**: High-contrast typography using the 'Outfit' typeface.
/// - **Tactility**: Subtle borders and glass effects for interactive elements.
class AethericTheme {
  // --- Brand Colors ---

  /// The primary background color (extremely dark blue/slate).
  static const Color deepVoid = Color(0xFF020617);

  /// The core accent color (vibrant sky blue).
  static const Color aetherBlue = Color(0xFF38BDF8);

  /// The base translucent color for glassmorphic containers.
  static const Color crystalline = Color(0x1AFFFFFF);

  /// Slightly lighter glass surface for interactive elements.
  static const Color glassSurface = Color(0x0FFFFFFF);

  /// The subtle border color for glass containers.
  static const Color glassBorder = Color(0x33FFFFFF);

  /// Semantic Color: Tech Green (Krypton)
  static const Color kryptonGreen = Color(0xFF00FF9D);

  /// Semantic Color: Success (Green)
  static const Color success = Color(0xFF10B981);

  /// Semantic Color: Warning (Amber)
  static const Color warning = Color(0xFFF59E0B);

  /// Semantic Color: Error (Red)
  static const Color error = Color(0xFFEF4444);

  /// Semantic Color: Info (Blue)
  static const Color info = Color(0xFF3B82F6);

  /// Generates the global [ThemeData] for the application.
  ///
  /// Configures Material 3, dark brightness, and custom component themes
  /// for buttons and typography.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepVoid,

      // Color scheme derived from the brand Aether Blue
      colorScheme: ColorScheme.fromSeed(
        seedColor: aetherBlue,
        brightness: Brightness.dark,
        surface: deepVoid,
      ),

      // Custom typography using 'Outfit' (must be included in pubspec)
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(fontFamily: 'Outfit', color: Colors.white70),
      ),

      // Integrated glassmorphic button styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: crystalline,
          foregroundColor: Colors.white,
          side: const BorderSide(color: glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

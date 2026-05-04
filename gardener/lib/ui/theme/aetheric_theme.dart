import 'package:flutter/material.dart';

/// The core design system and theme definition for SeedSphere.
class AethericTheme {
  /// Safe typography helper.
  static TextStyle outfit({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    // Return standard TextStyle to avoid any dependency on external font loaders.
    return (textStyle ?? const TextStyle()).copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

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
      textTheme: TextTheme(
        headlineMedium: outfit(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: outfit(color: Colors.white70),
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

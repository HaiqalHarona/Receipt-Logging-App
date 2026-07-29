import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

/// App Theme & Design Tokens for Receipt Logger
/// Features Neumorphic design system for Light & Dark mode.
class AppTheme {
  // ── Color Tokens ─────────────────────────────────────────────────────────────

  // Dark Theme Tokens (Pinkish Red / Neon Rose Accent)
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkCardBackground = Color(0xFF252540);
  static const Color darkAccentPinkishRed = Color(0xFFFF2A6D); // #FF2A6D Neon Rose
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Light Theme Tokens (Neumorphic Silver & Teal Accent)
  static const Color lightBackground = Color(0xFFE0E5EC);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAccentTeal = Color(0xFF0D9488);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ── Neumorphic Theme Data ───────────────────────────────────────────────────

  /// Dark Neumorphic Theme with Pinkish Red Accent
  static NeumorphicThemeData get darkNeumorphicTheme {
    return const NeumorphicThemeData(
      baseColor: darkBackground,
      accentColor: darkAccentPinkishRed,
      variantColor: darkCardBackground,
      lightSource: LightSource.topLeft,
      depth: 4,
      intensity: 0.6,
      shadowDarkColor: Color(0xFF12121F),
      shadowLightColor: Color(0xFF262642),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),
    );
  }

  /// Light Neumorphic Theme with Crisp Legibility & Soft Shadows
  static NeumorphicThemeData get lightNeumorphicTheme {
    return const NeumorphicThemeData(
      baseColor: lightBackground,
      accentColor: lightAccentTeal,
      variantColor: lightCardBackground,
      lightSource: LightSource.topLeft,
      depth: 5,
      intensity: 0.7,
      shadowDarkColor: Color(0xFFA3B1C6),
      shadowLightColor: Color(0xFFFFFFFF),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextSecondary),
      ),
    );
  }
}

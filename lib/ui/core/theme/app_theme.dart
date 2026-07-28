import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

class AppTheme {
  // ── Light Neumorphic Palette ──────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFE0E5EC);
  static const Color lightShadowDark = Color(0xFFA3B1C6);
  static const Color lightShadowLight = Color(0xFFFFFFFF);
  static const Color accentColor = Color(0xFF6C63FF);
  static const Color accentLight = Color(0xFF9D97FF);
  static const Color successColor = Color(0xFF4CAF82);
  static const Color warningColor = Color(0xFFFFB347);
  static const Color errorColor = Color(0xFFE57373);
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textMuted = Color(0xFFA0AEC0);

  // ── Dark Neumorphic Palette ───────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF1E2027);
  static const Color darkShadowDark = Color(0xFF15171D);
  static const Color darkShadowLight = Color(0xFF2B2F3E);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFFA0AEC0);

  // ── Dynamic Helper Colors ──────────────────────────────────────────────────
  static Color backgroundColorOf(BuildContext context) =>
      NeumorphicTheme.isUsingDark(context) ? darkBackground : lightBackground;

  static Color textPrimaryOf(BuildContext context) =>
      NeumorphicTheme.isUsingDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      NeumorphicTheme.isUsingDark(context) ? darkTextSecondary : textSecondary;

  static NeumorphicThemeData get lightTheme => const NeumorphicThemeData(
        baseColor: lightBackground,
        lightSource: LightSource.topLeft,
        depth: 8,
        intensity: 0.6,
        shadowLightColor: lightShadowLight,
        shadowDarkColor: lightShadowDark,
        shadowLightColorEmboss: lightShadowLight,
        shadowDarkColorEmboss: lightShadowDark,
        defaultTextColor: textPrimary,
        accentColor: accentColor,
        variantColor: textSecondary,
        disabledColor: textMuted,
        borderColor: Colors.transparent,
        borderWidth: 0,
        appBarTheme: NeumorphicAppBarThemeData(
          color: lightBackground,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      );

  static NeumorphicThemeData get darkTheme => const NeumorphicThemeData(
        baseColor: darkBackground,
        lightSource: LightSource.topLeft,
        depth: 6,
        intensity: 0.6,
        shadowLightColor: darkShadowLight,
        shadowDarkColor: darkShadowDark,
        shadowLightColorEmboss: darkShadowLight,
        shadowDarkColorEmboss: darkShadowDark,
        defaultTextColor: darkTextPrimary,
        accentColor: accentColor,
        variantColor: darkTextSecondary,
        disabledColor: textMuted,
        borderColor: Colors.transparent,
        borderWidth: 0,
        appBarTheme: NeumorphicAppBarThemeData(
          color: darkBackground,
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: darkTextPrimary,
          ),
        ),
      );

  // ── Reusable NeumorphicStyle presets ───────────────────────────────────────
  static NeumorphicStyle get cardStyle => NeumorphicStyle(
        depth: 8,
        intensity: 0.7,
        surfaceIntensity: 0.1,
        shape: NeumorphicShape.flat,
        lightSource: LightSource.topLeft,
        boxShape: NeumorphicBoxShape.roundRect(
          const BorderRadius.all(Radius.circular(20)),
        ),
      );

  static NeumorphicStyle get buttonStyle => NeumorphicStyle(
        depth: 6,
        intensity: 0.8,
        shape: NeumorphicShape.convex,
        lightSource: LightSource.topLeft,
        boxShape: NeumorphicBoxShape.roundRect(
          const BorderRadius.all(Radius.circular(16)),
        ),
      );

  static NeumorphicStyle get insetStyle => NeumorphicStyle(
        depth: -4,
        intensity: 0.8,
        shape: NeumorphicShape.flat,
        lightSource: LightSource.topLeft,
        boxShape: NeumorphicBoxShape.roundRect(
          const BorderRadius.all(Radius.circular(16)),
        ),
      );

  static NeumorphicStyle get fabStyle => NeumorphicStyle(
        depth: 10,
        intensity: 0.9,
        shape: NeumorphicShape.convex,
        lightSource: LightSource.topLeft,
        color: accentColor,
        boxShape: const NeumorphicBoxShape.circle(),
      );

  static NeumorphicStyle get chipStyle => const NeumorphicStyle(
        depth: 4,
        intensity: 0.7,
        shape: NeumorphicShape.flat,
        lightSource: LightSource.topLeft,
        boxShape: NeumorphicBoxShape.stadium(),
      );

  // ── Text Styles ────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.5,
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: accentColor,
    letterSpacing: -0.5,
  );
}

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

/// App Theme & Design Tokens for Receipt Logger
/// Features Neumorphic design system for Light & Dark mode.
class AppTheme {
  // ── Color Tokens ─────────────────────────────────────────────────────────────

  // Dark Theme Tokens (Classic Charcoal & Neon Emerald Accent)
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkCardBackground = Color(0xFF1E1E1E); // Camouflage Rule: exact same hex
  static const Color darkAccentPinkishRed = Color(0xFF00FF85); // #00FF85 Neon Emerald Accent
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);

  // Light Theme Tokens (Neumorphic Silver & Teal Accent)
  static const Color lightBackground = Color(0xFFE0E5EC);
  static const Color lightCardBackground = Color(0xFFE0E5EC);
  static const Color lightAccentTeal = Color(0xFF0D9488);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ── Neumorphic Theme Data ───────────────────────────────────────────────────

  /// Dark Neumorphic Theme with Classic Charcoal Base & #00FF85 Accent
  static NeumorphicThemeData get darkNeumorphicTheme {
    return NeumorphicThemeData(
      baseColor: darkBackground,
      accentColor: darkAccentPinkishRed,
      variantColor: darkCardBackground,
      lightSource: LightSource.topLeft,
      depth: 6,
      intensity: 0.9,
      shadowDarkColor: const Color(0xFF0D0D14),
      shadowLightColor: const Color(0xFF4A4A60), // Brighter crisp top-left highlight
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),
    );
  }


  /// Light Neumorphic Theme with Crisp Legibility & Soft Shadows
  static NeumorphicThemeData get lightNeumorphicTheme {
    return NeumorphicThemeData(
      baseColor: lightBackground,
      accentColor: lightAccentTeal,
      variantColor: lightCardBackground,
      lightSource: LightSource.topLeft,
      depth: 5,
      intensity: 0.7,
      shadowDarkColor: const Color(0xFFA3B1C6),
      shadowLightColor: const Color(0xFFFFFFFF),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextSecondary),
      ),
    );
  }
}



/// ── Reusable Neumorphic UI Components ──────────────────────────────────────

/// Universal Neumorphic Card Container
class NeumorphicCardWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double depth;
  final double intensity;
  final Color? color;
  final VoidCallback? onTap;

  const NeumorphicCardWidget({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.depth = 4,
    this.intensity = 0.6,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final cardColor = color ?? (isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground);

    final card = Neumorphic(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(16),
      style: NeumorphicStyle(
        depth: depth,
        intensity: intensity,
        color: cardColor,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

/// Interactive Neumorphic Button
class NeumorphicButtonWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double borderRadius;
  final double depth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const NeumorphicButtonWidget({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.borderRadius = 12,
    this.depth = 4,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final btnColor = color ?? (isDark ? AppTheme.darkAccentPinkishRed : AppTheme.lightAccentTeal);

    return Container(
      margin: margin,
      child: NeumorphicButton(
        onPressed: onPressed,
        style: NeumorphicStyle(
          color: btnColor,
          depth: depth,
          intensity: 0.7,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
        ),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      ),
    );
  }
}

/// Embossed (Inner Shadow) Input Field Container
class NeumorphicInputFieldWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final double depth;

  const NeumorphicInputFieldWidget({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 12,
    this.depth = -3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Neumorphic(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      style: NeumorphicStyle(
        depth: depth,
        intensity: 0.8,
        color: bg,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
      ),
      child: child,
    );
  }
}


/// Circular Neumorphic Icon Badge Wrapper
class NeumorphicIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final double depth;
  final bool isInset;
  final VoidCallback? onTap;

  const NeumorphicIconBadge({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconSize = 20,
    this.depth = 3,
    this.isInset = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final accent = isDark ? AppTheme.darkAccentPinkishRed : AppTheme.lightAccentTeal;
    final base = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    final widget = Neumorphic(
      style: NeumorphicStyle(
        depth: isInset ? -depth : depth,
        boxShape: NeumorphicBoxShape.circle(),

        color: base,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: iconColor ?? accent,
          size: iconSize,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: widget,
      );
    }
    return widget;
  }
}


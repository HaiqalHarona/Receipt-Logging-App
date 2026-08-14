import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'theme_controller.dart';

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
      intensity: 0.85,
      // Reduced highlight to prevent harsh bright edge cut in dark mode
      shadowDarkColor: const Color(0xFF080810),
      shadowLightColor: const Color(0xFF303048),
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
    this.depth = 6,
    this.intensity = 0.85,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.themeMode == ThemeMode.dark;
    final cardColor = color ?? controller.currentBaseColor;

    final card = Neumorphic(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(16),
      style: NeumorphicStyle(
        depth: depth,
        intensity: intensity,
        color: cardColor,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
        border: NeumorphicBorder(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          width: 0.8,
        ),
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
    this.borderRadius = 14,
    this.depth = 6,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final bool isDisabled = onPressed == null;
    final baseBtnColor = color ?? controller.accentColor;

    final hsl = HSLColor.fromColor(baseBtnColor);
    final effectiveColor = isDisabled
        ? hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor()
        : baseBtnColor;

    final effectiveDepth = isDisabled ? -4.0 : depth;

    return Container(
      margin: margin,
      child: NeumorphicButton(
        onPressed: onPressed,
        style: NeumorphicStyle(
          color: effectiveColor,
          depth: effectiveDepth,
          intensity: isDisabled ? 0.85 : 0.9,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
          border: NeumorphicBorder(
            color: isDisabled
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
    this.borderRadius = 14,
    this.depth = -4,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.themeMode == ThemeMode.dark;
    final bg = controller.currentBaseColor;

    return Neumorphic(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      style: NeumorphicStyle(
        depth: depth,
        intensity: 0.9,
        color: bg,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
        border: NeumorphicBorder(
          color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
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
    this.depth = 5,
    this.isInset = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.themeMode == ThemeMode.dark;
    final accent = controller.accentColor;
    final base = controller.currentBaseColor;

    final widget = Neumorphic(
      style: NeumorphicStyle(
        depth: isInset ? -depth : depth,
        intensity: 0.85,
        boxShape: const NeumorphicBoxShape.circle(),
        color: base,
        border: NeumorphicBorder(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
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



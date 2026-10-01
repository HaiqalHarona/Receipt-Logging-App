import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'theme_controller.dart';

/// App Theme & Design Tokens for Receipt Logger
/// Features Neumorphic design system for Light & Dark mode.
class AppTheme {
  // ── Color Tokens ─────────────────────────────────────────────────────────────

  // Dark Theme Tokens (Classic Charcoal & Neon Emerald Accent)
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkCardBackground =
      Color(0xFF1E1E1E); // Camouflage Rule: exact same hex
  static const Color darkAccentPinkishRed =
      Color(0xFF00FF85); // #00FF85 Neon Emerald Accent
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
    return const NeumorphicThemeData(
      baseColor: darkBackground,
      accentColor: darkAccentPinkishRed,
      variantColor: darkCardBackground,
      lightSource: LightSource.topLeft,
      depth: 6,
      intensity: 0.85,
      // Reduced highlight to prevent harsh bright edge cut in dark mode
      shadowDarkColor: Color(0xFF080810),
      shadowLightColor: Color(0xFF282838),
      shadowDarkColorEmboss: Color(0xB3000000),
      shadowLightColorEmboss: Color(0x28FFFFFF),
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
      shadowDarkColorEmboss: Color(0xFFA3B1C6),
      shadowLightColorEmboss: Color(0xFFFFFFFF),
      textTheme: TextTheme(
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
  final double? depth;
  final double intensity;
  final Color? color;
  final VoidCallback? onTap;

  const NeumorphicCardWidget({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.depth,
    this.intensity = 0.85,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final cardColor = color ?? controller.currentBaseColor;
    final effectiveDepth = depth ?? controller.neuDepth;

    final card = Neumorphic(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(16),
      style: NeumorphicStyle(
        depth: effectiveDepth,
        intensity: intensity,
        color: cardColor,
        boxShape:
            NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
        border: NeumorphicBorder(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
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
  final double? depth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const NeumorphicButtonWidget({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.borderRadius = 14,
    this.depth,
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

    final effectiveDepth = isDisabled ? 1.0 : (depth ?? controller.neuDepth);

    return Container(
      margin: margin,
      child: NeumorphicButton(
        onPressed: onPressed,
        style: NeumorphicStyle(
          color: effectiveColor,
          depth: effectiveDepth,
          intensity: isDisabled ? 0.4 : 0.9,
          boxShape:
              NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
          border: NeumorphicBorder(
            color: isDisabled
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
  final double? depth;

  const NeumorphicInputFieldWidget({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
    this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final bg = controller.currentBaseColor;
    final inputBg = isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.15), bg)
        : bg;

    final effectiveDepth =
        depth ?? -(controller.neuDepth.clamp(1.5, 3.5));

    return Neumorphic(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      style: NeumorphicStyle(
        depth: effectiveDepth,
        intensity: isDark ? 0.45 : 0.8,
        color: inputBg,
        shadowDarkColorEmboss: controller.shadowDarkColorEmboss,
        shadowLightColorEmboss: controller.shadowLightColorEmboss,
        boxShape:
            NeumorphicBoxShape.roundRect(BorderRadius.circular(borderRadius)),
        border: NeumorphicBorder(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}

/// Alias for NeumorphicInputFieldWidget
typedef NeumorphicInputFieldContainer = NeumorphicInputFieldWidget;

/// Circular Neumorphic Icon Badge Wrapper
class NeumorphicIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final double? depth;
  final bool isInset;
  final VoidCallback? onTap;

  const NeumorphicIconBadge({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconSize = 20,
    this.depth,
    this.isInset = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final accent = controller.accentColor;
    final base = controller.currentBaseColor;
    final effectiveDepth =
        depth ?? (controller.neuDepth * 0.75).clamp(2.0, 8.0);

    final widget = Neumorphic(
      style: NeumorphicStyle(
        depth: isInset ? -effectiveDepth : effectiveDepth,
        intensity: 0.85,
        boxShape: const NeumorphicBoxShape.circle(),
        color: base,
        border: NeumorphicBorder(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
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

/// Circular Interactive Neumorphic Button
class NeumorphicCircularButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double iconSize;
  final double padding;
  final Color? iconColor;
  final Color? color;
  final double depth;
  final String? tooltip;
  final bool isLoading;

  const NeumorphicCircularButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconSize = 20,
    this.padding = 8,
    this.iconColor,
    this.color,
    this.depth = 3,
    this.tooltip,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final baseColor = color ?? controller.currentBaseColor;

    final Widget content = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor ?? controller.accentColor,
            ),
          )
        : Icon(
            icon,
            color: iconColor ?? textPrimary,
            size: iconSize,
          );

    final Widget button;
    if (onTap == null && !isLoading) {
      button = Neumorphic(
        style: NeumorphicStyle(
          shape: NeumorphicShape.convex,
          boxShape: const NeumorphicBoxShape.circle(),
          depth: depth,
          intensity: 0.8,
          color: baseColor,
        ),
        padding: EdgeInsets.all(padding),
        child: content,
      );
    } else {
      button = NeumorphicButton(
        onPressed: isLoading ? null : onTap,
        style: NeumorphicStyle(
          shape: NeumorphicShape.convex,
          boxShape: const NeumorphicBoxShape.circle(),
          depth: depth,
          intensity: 0.8,
          color: baseColor,
        ),
        padding: EdgeInsets.all(padding),
        child: content,
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        triggerMode: TooltipTriggerMode.tap,
        child: button,
      );
    }
    return button;
  }
}

/// Reusable Neumorphic Toggle Switch
///
/// Features an embossed indented track (depth: -2.0) with a smooth sliding
/// protruded circular thumb (depth: 2.0) that illuminates with the theme
/// accent color when active.
class NeumorphicToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Color? activeThumbColor;
  final Color? inactiveThumbColor;

  const NeumorphicToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 52.0,
    this.height = 28.0,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.activeThumbColor,
    this.inactiveThumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final base = controller.currentBaseColor;
    final accent = controller.accentColor;
    final isEnabled = onChanged != null;

    final trackColor = value
        ? (activeTrackColor ?? accent.withValues(alpha: isDark ? 0.35 : 0.25))
        : (inactiveTrackColor ?? base);

    final thumbColor = value
        ? (activeThumbColor ?? accent)
        : (inactiveThumbColor ?? (isDark ? Colors.grey.shade400 : Colors.white));

    final thumbSize = height - 6.0;

    return Semantics(
      toggled: value,
      enabled: isEnabled,
      child: GestureDetector(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.45,
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: -2.0,
              intensity: 0.85,
              color: trackColor,
              boxShape: NeumorphicBoxShape.roundRect(
                BorderRadius.circular(height / 2),
              ),
              border: NeumorphicBorder(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                width: 0.8,
              ),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: Neumorphic(
                    style: NeumorphicStyle(
                      shape: NeumorphicShape.convex,
                      depth: 2.0,
                      intensity: 0.85,
                      color: thumbColor,
                      boxShape: const NeumorphicBoxShape.circle(),
                      shadowLightColor: isDark ? Colors.white12 : Colors.white,
                    ),
                    child: SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


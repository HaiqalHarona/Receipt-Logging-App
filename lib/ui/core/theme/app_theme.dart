import 'dart:async';
import 'package:flutter/services.dart';
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
/// Universal tactile neumorphic button that flattens to depth 0.0
/// and triggers instantaneous haptic feedback on touch down.
class NeumorphicTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double depth;
  final double pressedDepth;
  final double pressedScale;
  final Duration duration;
  final Curve curve;
  final Color? color;
  final NeumorphicBoxShape? boxShape;
  final NeumorphicBorder? border;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final NeumorphicShape shape;
  final double intensity;
  final bool provideHapticFeedback;
  final String? tooltip;
  final bool isLoading;

  final bool? enabled;

  const NeumorphicTactileButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.enabled,
    this.depth = 4.0,
    this.pressedDepth = 0.0,
    this.pressedScale = 0.98,
    this.duration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOut,
    this.color,
    this.boxShape,
    this.border,
    this.padding,
    this.margin,
    this.shape = NeumorphicShape.flat,
    this.intensity = 0.85,
    this.provideHapticFeedback = true,
    this.tooltip,
    this.isLoading = false,
  });

  bool get isEnabled => (enabled ?? (onPressed != null)) && !isLoading;

  @override
  State<NeumorphicTactileButton> createState() => _NeumorphicTactileButtonState();
}

class _NeumorphicTactileButtonState extends State<NeumorphicTactileButton> {
  bool _isPressed = false;
  DateTime? _tapDownTime;
  Timer? _dwellTimer;

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();

    if (widget.provideHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    _tapDownTime = DateTime.now();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;

    widget.onPressed?.call();

    if (_tapDownTime != null) {
      final elapsed = DateTime.now().difference(_tapDownTime!).inMilliseconds;
      if (elapsed < 75) {
        _dwellTimer?.cancel();
        _dwellTimer = Timer(Duration(milliseconds: 75 - elapsed), () {
          if (mounted) setState(() => _isPressed = false);
        });
        return;
      }
    }

    if (mounted) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDepth = !widget.isEnabled
        ? 0.0
        : (_isPressed ? widget.pressedDepth : widget.depth);

    final effectiveScale = (!widget.isEnabled || !_isPressed)
        ? 1.0
        : widget.pressedScale;

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: effectiveScale,
        duration: widget.duration,
        curve: widget.curve,
        alignment: Alignment.center,
        child: Neumorphic(
          margin: widget.margin ?? EdgeInsets.zero,
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          duration: widget.duration,
          curve: widget.curve,
          style: NeumorphicStyle(
            shape: widget.shape,
            depth: effectiveDepth,
            intensity: widget.isEnabled ? widget.intensity : 0.4,
            color: widget.color,
            boxShape: widget.boxShape ??
                NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
            border: widget.border ?? const NeumorphicBorder.none(),
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        triggerMode: TooltipTriggerMode.tap,
        child: button,
      );
    }
    return button;
  }
}

/// Interactive Neumorphic Button with instant tactile flatten behavior.
class NeumorphicButtonWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double borderRadius;
  final double? depth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool isLoading;

  const NeumorphicButtonWidget({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.borderRadius = 14,
    this.depth,
    this.padding,
    this.margin,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final bool isDisabled = onPressed == null || isLoading;
    final baseBtnColor = color ?? controller.accentColor;

    final hsl = HSLColor.fromColor(baseBtnColor);
    final effectiveColor = isDisabled
        ? hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor()
        : baseBtnColor;

    final effectiveDepth = isDisabled ? 1.0 : (depth ?? controller.neuDepth);

    return Container(
      margin: margin,
      child: NeumorphicTactileButton(
        onPressed: isDisabled ? null : onPressed,
        depth: effectiveDepth,
        pressedDepth: 0.0,
        pressedScale: 0.98,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        color: effectiveColor,
        boxShape: NeumorphicBoxShape.roundRect(
            BorderRadius.circular(borderRadius)),
        border: NeumorphicBorder(
          color: isDisabled
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.25),
          width: 1.0,
        ),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        isLoading: isLoading,
        child: child,
      ),
    );
  }
}

/// Tactile pressable list row designed for grouped cards (e.g. inside NeumorphicCardWidget).
/// On press-down, displays an inner debossed/sunken effect (depth: -1.5) with immediate
/// light haptic feedback, returning flush on release without affecting the parent card.
class NeumorphicPressableRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  final double debossDepth;
  final Duration duration;
  final Curve curve;
  final Color? color;
  final bool provideHapticFeedback;

  const NeumorphicPressableRow({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.debossDepth = -1.5,
    this.duration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOut,
    this.color,
    this.provideHapticFeedback = true,
  });

  bool get isEnabled => onTap != null;

  @override
  State<NeumorphicPressableRow> createState() => _NeumorphicPressableRowState();
}

class _NeumorphicPressableRowState extends State<NeumorphicPressableRow> {
  bool _isPressed = false;
  DateTime? _tapDownTime;
  Timer? _dwellTimer;

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();
    if (widget.provideHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    _tapDownTime = DateTime.now();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    widget.onTap?.call();

    if (_tapDownTime != null) {
      final elapsed = DateTime.now().difference(_tapDownTime!).inMilliseconds;
      if (elapsed < 75) {
        _dwellTimer?.cancel();
        _dwellTimer = Timer(Duration(milliseconds: 75 - elapsed), () {
          if (mounted) setState(() => _isPressed = false);
        });
        return;
      }
    }
    if (mounted) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final baseColor = widget.color ?? controller.currentBaseColor;

    final effectiveDepth =
        (!widget.isEnabled || !_isPressed) ? 0.0 : widget.debossDepth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.99 : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        alignment: Alignment.center,
        child: Neumorphic(
          duration: widget.duration,
          curve: widget.curve,
          padding: widget.padding,
          style: NeumorphicStyle(
            depth: effectiveDepth,
            intensity: isDark ? 0.45 : 0.8,
            color: baseColor,
            shadowDarkColorEmboss: controller.shadowDarkColorEmboss,
            shadowLightColorEmboss: controller.shadowLightColorEmboss,
            boxShape: NeumorphicBoxShape.roundRect(
              widget.borderRadius ?? BorderRadius.circular(14),
            ),
            border: const NeumorphicBorder.none(),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Selectable Neumorphic Filter Chip and Sort Toggle.
/// Features instant tactile flatten (to depth 0.0) with zero-latency haptics on press-down.
/// On release, latches into an indented/embossed state (depth -2.5) with accent tint.
/// Tapping an active chip unlatches it back to raised (depth 3.0).
class NeumorphicFilterChip extends StatefulWidget {
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onTap;
  final Widget? child;
  final Widget Function(BuildContext context, bool isSelected, bool isPressed)?
      builder;
  final String? label;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double restDepth;
  final double selectedDepth;
  final double pressedDepth;
  final double pressedScale;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final Duration duration;
  final Curve curve;
  final bool isEnabled;
  final bool provideHapticFeedback;
  final NeumorphicBorder? border;

  const NeumorphicFilterChip({
    super.key,
    required this.isSelected,
    this.onSelected,
    this.onTap,
    this.child,
    this.builder,
    this.label,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.restDepth = 3.0,
    this.selectedDepth = -2.5,
    this.pressedDepth = 0.0,
    this.pressedScale = 0.97,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.duration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOut,
    this.isEnabled = true,
    this.provideHapticFeedback = true,
    this.border,
  });

  @override
  State<NeumorphicFilterChip> createState() => _NeumorphicFilterChipState();
}

class _NeumorphicFilterChipState extends State<NeumorphicFilterChip> {
  bool _isPressed = false;
  DateTime? _tapDownTime;
  Timer? _dwellTimer;

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();
    if (widget.provideHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    _tapDownTime = DateTime.now();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    if (widget.onSelected != null) {
      widget.onSelected!(!widget.isSelected);
    } else if (widget.onTap != null) {
      widget.onTap!();
    }

    if (_tapDownTime != null) {
      final elapsed = DateTime.now().difference(_tapDownTime!).inMilliseconds;
      if (elapsed < 75) {
        _dwellTimer?.cancel();
        _dwellTimer = Timer(Duration(milliseconds: 75 - elapsed), () {
          if (mounted) setState(() => _isPressed = false);
        });
        return;
      }
    }
    if (mounted) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    _dwellTimer?.cancel();
    if (mounted) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final isDark = controller.isDarkMode;
    final accent = controller.accentColor;
    final base = controller.currentBaseColor;
    final textPrimary = controller.textColor;

    final double effectiveDepth;
    if (!widget.isEnabled) {
      effectiveDepth = 0.0;
    } else if (_isPressed) {
      effectiveDepth = widget.pressedDepth;
    } else {
      effectiveDepth =
          widget.isSelected ? widget.selectedDepth : widget.restDepth;
    }

    final effectiveColor = widget.isSelected
        ? (widget.selectedColor ?? accent)
        : (widget.unselectedColor ?? base);

    final effectiveTextColor = widget.isSelected
        ? (widget.selectedTextColor ?? Colors.white)
        : (widget.unselectedTextColor ?? textPrimary);

    Widget chipContent;
    if (widget.builder != null) {
      chipContent = widget.builder!(context, widget.isSelected, _isPressed);
    } else if (widget.child != null) {
      chipContent = widget.child!;
    } else {
      chipContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: 15,
              color: effectiveTextColor,
            ),
            if (widget.label != null) const SizedBox(width: 6),
          ],
          if (widget.label != null)
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    widget.isSelected ? FontWeight.bold : FontWeight.w500,
                color: effectiveTextColor,
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: (!widget.isEnabled || !_isPressed) ? 1.0 : widget.pressedScale,
        duration: widget.duration,
        curve: widget.curve,
        alignment: Alignment.center,
        child: Neumorphic(
          duration: widget.duration,
          curve: widget.curve,
          padding: widget.padding,
          style: NeumorphicStyle(
            depth: effectiveDepth,
            intensity: widget.isEnabled ? (isDark ? 0.55 : 0.8) : 0.3,
            color: effectiveColor,
            shadowDarkColorEmboss: controller.shadowDarkColorEmboss,
            shadowLightColorEmboss: controller.shadowLightColorEmboss,
            boxShape: NeumorphicBoxShape.roundRect(widget.borderRadius),
            border: widget.isSelected
                ? NeumorphicBorder(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                    width: 0.8,
                  )
                : NeumorphicBorder(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    width: 0.8,
                  ),
          ),
          child: chipContent,
        ),
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
      if (!isInset) {
        return NeumorphicTactileButton(
          onPressed: onTap,
          depth: effectiveDepth,
          pressedDepth: 0.0,
          pressedScale: 0.96,
          color: base,
          boxShape: const NeumorphicBoxShape.circle(),
          border: NeumorphicBorder(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.6),
            width: 0.8,
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: iconColor ?? accent,
            size: iconSize,
          ),
        );
      }
      return GestureDetector(
        onTap: onTap,
        child: widget,
      );
    }
    return widget;
  }
}

/// Circular Interactive Neumorphic Button with instant tactile flatten behavior.
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
  final NeumorphicShape shape;
  final NeumorphicBorder? border;
  final bool? enabled;

  const NeumorphicCircularButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconSize = 20,
    this.padding = 8,
    this.iconColor,
    this.color,
    this.depth = 4.0,
    this.tooltip,
    this.isLoading = false,
    this.shape = NeumorphicShape.convex,
    this.border,
    this.enabled,
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

    return NeumorphicTactileButton(
      onPressed: isLoading ? null : onTap,
      enabled: enabled,
      depth: depth,
      pressedDepth: 0.0,
      pressedScale: 0.96,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      color: baseColor,
      shape: shape,
      boxShape: const NeumorphicBoxShape.circle(),
      border: border,
      padding: EdgeInsets.all(padding),
      tooltip: tooltip,
      isLoading: isLoading,
      child: content,
    );
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


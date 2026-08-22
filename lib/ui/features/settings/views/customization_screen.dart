// File: lib/ui/features/settings/views/customization_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  // Local HSL state for the accent colour picker
  double _hue = 160.0;
  double _sat = 1.0;
  double _lit = 0.50;

  @override
  void initState() {
    super.initState();
    _syncHslFromController();
  }

  void _syncHslFromController() {
    final hsl = HSLColor.fromColor(AppThemeController.instance.accentColor);
    _hue = hsl.hue;
    _sat = hsl.saturation;
    _lit = hsl.lightness;
  }

  Color get _previewAccent =>
      HSLColor.fromAHSL(1.0, _hue, _sat.clamp(0.0, 1.0), _lit.clamp(0.0, 1.0))
          .toColor();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final isDark = controller.isDarkMode;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──────────────────────────────────────────
                          Row(
                            children: [
                              NeumorphicIconBadge(
                                icon: Icons.arrow_back_rounded,
                                iconSize: 20,
                                onTap: () => context.pop(),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Theme Customization',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Section: Theme Mode ──────────────────────────────
                          _SectionLabel(
                              label: 'APPEARANCE MODE',
                              textSecondary: textSecondary),
                          const SizedBox(height: 12),
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ModeChip(
                                    icon: Icons.dark_mode_rounded,
                                    label: 'Dark',
                                    isSelected:
                                        controller.themeMode == ThemeMode.dark,
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    onTap: () =>
                                        controller.setThemeMode(ThemeMode.dark),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ModeChip(
                                    icon: Icons.light_mode_rounded,
                                    label: 'Light',
                                    isSelected:
                                        controller.themeMode == ThemeMode.light,
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    onTap: () => controller
                                        .setThemeMode(ThemeMode.light),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ModeChip(
                                    icon: Icons.phone_android_rounded,
                                    label: 'Auto',
                                    isSelected: controller.themeMode ==
                                        ThemeMode.system,
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    onTap: () => controller
                                        .setThemeMode(ThemeMode.system),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Section: Colour Palette Presets ─────────────────
                          _SectionLabel(
                            label: isDark
                                ? 'DARK MODE PRESETS'
                                : 'LIGHT MODE PRESETS',
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: AppThemeController.currentPresets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final presets = AppThemeController.currentPresets;
                          final preset = presets[index];
                          final isSelected =
                              controller.selectedPresetIndex == index;
                          final previewBase = isDark
                              ? preset.darkBaseColor
                              : preset.lightBaseColor;
                          final previewAccent = isDark
                              ? preset.darkAccentColor
                              : preset.lightAccentColor;
                          final previewText = isDark
                              ? preset.darkTextColor
                              : preset.lightTextColor;

                          return GestureDetector(
                            onTap: () {
                              controller.selectPreset(index);
                              _syncHslFromController();
                              setState(() {});
                            },
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                depth: isSelected ? -3 : 4,
                                intensity: 0.85,
                                color: previewBase,
                                boxShape: NeumorphicBoxShape.roundRect(
                                  BorderRadius.circular(14),
                                ),
                                border: NeumorphicBorder(
                                  color: isSelected
                                      ? previewAccent
                                      : previewAccent.withValues(alpha: 0.4),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: previewAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          preset.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: previewText,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: previewAccent,
                                            size: 13,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Section: Custom Accent Colour ────────────────────
                          _SectionLabel(
                              label: 'BUTTON & ACCENT COLOR',
                              textSecondary: textSecondary),
                          const SizedBox(height: 12),
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live preview swatch + current hex
                                Row(
                                  children: [
                                    Neumorphic(
                                      style: NeumorphicStyle(
                                        depth: -4,
                                        intensity: 0.9,
                                        color: _previewAccent,
                                        boxShape:
                                            const NeumorphicBoxShape.circle(),
                                      ),
                                      child:
                                          const SizedBox(width: 52, height: 52),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Custom Accent',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '#${_previewAccent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Hue slider with rainbow gradient
                                _SliderLabel(
                                    label: 'Hue',
                                    value: '${_hue.round()}°',
                                    accent: accent,
                                    textSecondary: textSecondary),
                                const SizedBox(height: 4),
                                _HueSlider(
                                  value: _hue,
                                  onChanged: (v) {
                                    setState(() => _hue = v);
                                    controller.updateCustomAccentColor(
                                        _previewAccent);
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Saturation slider
                                _SliderLabel(
                                    label: 'Saturation',
                                    value: '${(_sat * 100).round()}%',
                                    accent: accent,
                                    textSecondary: textSecondary),
                                const SizedBox(height: 4),
                                SliderTheme(
                                  data: _sliderTheme(context, accent),
                                  child: Slider(
                                    value: _sat,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (v) {
                                      setState(() => _sat = v);
                                      controller.updateCustomAccentColor(
                                          _previewAccent);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Lightness slider
                                _SliderLabel(
                                    label: 'Lightness',
                                    value: '${(_lit * 100).round()}%',
                                    accent: accent,
                                    textSecondary: textSecondary),
                                const SizedBox(height: 4),
                                SliderTheme(
                                  data: _sliderTheme(context, accent),
                                  child: Slider(
                                    value: _lit,
                                    min: 0.1,
                                    max: 0.9,
                                    onChanged: (v) {
                                      setState(() => _lit = v);
                                      controller.updateCustomAccentColor(
                                          _previewAccent);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Reset button
                                SizedBox(
                                  width: double.infinity,
                                  child: NeumorphicButtonWidget(
                                    onPressed: () {
                                      controller.resetToPreset();
                                      _syncHslFromController();
                                      setState(() {});
                                    },
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: 10,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Center(
                                      child: Text(
                                        'Reset to Preset',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Section: Neumorphic Depth ────────────────────────
                          _SectionLabel(
                              label: 'NEUMORPHIC DEPTH',
                              textSecondary: textSecondary),
                          const SizedBox(height: 12),
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Shadow Depth',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      controller.neuDepth.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Flat',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary)),
                                    Expanded(
                                      child: SliderTheme(
                                        data: _sliderTheme(context, accent),
                                        child: Slider(
                                          value: controller.neuDepth,
                                          min: 3.0,
                                          max: 10.0,
                                          divisions: 14,
                                          onChanged: (v) =>
                                              controller.setDepth(v),
                                        ),
                                      ),
                                    ),
                                    Text('Deep',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Section: Font Scale ──────────────────────────────
                          _SectionLabel(
                              label: 'TEXT SIZE', textSecondary: textSecondary),
                          const SizedBox(height: 12),
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                    child: _FontScaleChip(
                                        label: 'S',
                                        scale: 0.85,
                                        controller: controller,
                                        accent: accent,
                                        textPrimary: textPrimary)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _FontScaleChip(
                                        label: 'M',
                                        scale: 1.0,
                                        controller: controller,
                                        accent: accent,
                                        textPrimary: textPrimary)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _FontScaleChip(
                                        label: 'L',
                                        scale: 1.15,
                                        controller: controller,
                                        accent: accent,
                                        textPrimary: textPrimary)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _FontScaleChip(
                                        label: 'XL',
                                        scale: 1.3,
                                        controller: controller,
                                        accent: accent,
                                        textPrimary: textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  SliderThemeData _sliderTheme(BuildContext context, Color accent) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: accent,
      inactiveTrackColor: accent.withValues(alpha: 0.2),
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.1),
      trackHeight: 3.0,
    );
  }
}

// ── Shared Section Label ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textSecondary;

  const _SectionLabel({required this.label, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Mode Chip ────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accent;
  final Color textPrimary;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: isSelected ? -3 : 4,
          intensity: 0.85,
          color: isSelected ? accent.withValues(alpha: 0.12) : null,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
          border: isSelected
              ? NeumorphicBorder(
                  color: accent.withValues(alpha: 0.4), width: 1.0)
              : const NeumorphicBorder.none(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? accent : textPrimary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected ? accent : textPrimary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Font Scale Chip ──────────────────────────────────────────────────────────

class _FontScaleChip extends StatelessWidget {
  final String label;
  final double scale;
  final AppThemeController controller;
  final Color accent;
  final Color textPrimary;

  const _FontScaleChip({
    required this.label,
    required this.scale,
    required this.controller,
    required this.accent,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (controller.fontScale - scale).abs() < 0.01;
    return GestureDetector(
      onTap: () => controller.setFontScale(scale),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: isSelected ? -3 : 4,
          intensity: 0.85,
          color: isSelected ? accent.withValues(alpha: 0.12) : null,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
          border: isSelected
              ? NeumorphicBorder(
                  color: accent.withValues(alpha: 0.4), width: 1.0)
              : const NeumorphicBorder.none(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accent : textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Slider Row Label ─────────────────────────────────────────────────────────

class _SliderLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Color textSecondary;

  const _SliderLabel({
    required this.label,
    required this.value,
    required this.accent,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
      ],
    );
  }
}

// ── Hue Slider with Rainbow Gradient ─────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Rainbow gradient track
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF0000), // 0°   red
                        Color(0xFFFFFF00), // 60°  yellow
                        Color(0xFF00FF00), // 120° green
                        Color(0xFF00FFFF), // 180° cyan
                        Color(0xFF0000FF), // 240° blue
                        Color(0xFFFF00FF), // 300° magenta
                        Color(0xFFFF0000), // 360° red
                      ],
                    ),
                  ),
                ),
              ),
              // Transparent Slider on top
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: HSLColor.fromAHSL(1.0, value, 1.0, 0.5).toColor(),
                  overlayColor:
                      HSLColor.fromAHSL(0.15, value, 1.0, 0.5).toColor(),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 9),
                ),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 360.0,
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

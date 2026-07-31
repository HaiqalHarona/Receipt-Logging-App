import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

/// Theme Preset Definitions
class ThemePreset {
  final String name;
  final Color darkBaseColor;
  final Color darkAccentColor;
  final Color darkTextColor;
  final Color darkSecondaryTextColor;
  final Color lightBaseColor;
  final Color lightAccentColor;
  final Color lightTextColor;
  final Color lightSecondaryTextColor;

  const ThemePreset({
    required this.name,
    required this.darkBaseColor,
    required this.darkAccentColor,
    required this.darkTextColor,
    required this.darkSecondaryTextColor,
    required this.lightBaseColor,
    required this.lightAccentColor,
    required this.lightTextColor,
    required this.lightSecondaryTextColor,
  });
}

class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // Custom Colors
  Color? _customDarkAccentColor;
  Color? _customLightAccentColor;

  int _selectedDarkPresetIndex = 0;
  int _selectedLightPresetIndex = 0;

  int get selectedDarkPresetIndex => _selectedDarkPresetIndex;
  int get selectedLightPresetIndex => _selectedLightPresetIndex;

  int get selectedPresetIndex =>
      _themeMode == ThemeMode.dark ? _selectedDarkPresetIndex : _selectedLightPresetIndex;

  ThemePreset get currentPreset =>
      _themeMode == ThemeMode.dark ? darkPresets[_selectedDarkPresetIndex] : lightPresets[_selectedLightPresetIndex];

  Color get currentBaseColor {
    return _themeMode == ThemeMode.dark
        ? darkPresets[_selectedDarkPresetIndex].darkBaseColor
        : lightPresets[_selectedLightPresetIndex].lightBaseColor;
  }

  Color get currentAccentColor => accentColor;

  Color get accentColor {
    if (_themeMode == ThemeMode.dark) {
      return _customDarkAccentColor ?? darkPresets[_selectedDarkPresetIndex].darkAccentColor;
    } else {
      return _customLightAccentColor ?? lightPresets[_selectedLightPresetIndex].lightAccentColor;
    }
  }

  Color get textColor {
    return _themeMode == ThemeMode.dark
        ? darkPresets[_selectedDarkPresetIndex].darkTextColor
        : lightPresets[_selectedLightPresetIndex].lightTextColor;
  }

  Color get secondaryTextColor {
    return _themeMode == ThemeMode.dark
        ? darkPresets[_selectedDarkPresetIndex].darkSecondaryTextColor
        : lightPresets[_selectedLightPresetIndex].lightSecondaryTextColor;
  }

  Color get shadowDarkColor {
    final base = currentBaseColor;
    if (_themeMode == ThemeMode.dark) {
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness((hsl.lightness * 0.40).clamp(0.0, 1.0)).toColor();
    } else {
      final hsl = HSLColor.fromColor(base);
      return hsl
          .withHue(hsl.hue)
          .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
          .withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0))
          .toColor();
    }
  }

  Color get shadowLightColor {
    final base = currentBaseColor;
    if (_themeMode == ThemeMode.dark) {
      final hsl = HSLColor.fromColor(base);
      return hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
    } else {
      return Colors.white.withValues(alpha: 0.95);
    }
  }

  // Dark Mode Specific Presets
  static const List<ThemePreset> darkPresets = [
    ThemePreset(
      name: "Classic Charcoal",
      darkBaseColor: Color(0xFF1E1E1E),
      darkAccentColor: Color(0xFF00FF85),
      darkTextColor: Color(0xFFE0E0E0),
      darkSecondaryTextColor: Color(0xFFA0A0A0),
      lightBaseColor: Color(0xFFE2E8F0),
      lightAccentColor: Color(0xFF0D9488),
      lightTextColor: Color(0xFF0F172A),
      lightSecondaryTextColor: Color(0xFF475569),
    ),
    ThemePreset(
      name: "Neon Cyberpunk",
      darkBaseColor: Color(0xFF0F0F23),
      darkAccentColor: Color(0xFFF97316),
      darkTextColor: Color(0xFFF8FAFC),
      darkSecondaryTextColor: Color(0xFF94A3B8),
      lightBaseColor: Color(0xFFF1F5F9),
      lightAccentColor: Color(0xFFEA580C),
      lightTextColor: Color(0xFF020617),
      lightSecondaryTextColor: Color(0xFF64748B),
    ),
    ThemePreset(
      name: "Deep Ocean",
      darkBaseColor: Color(0xFF0D1B2A),
      darkAccentColor: Color(0xFF38BDF8),
      darkTextColor: Color(0xFFE0F2FE),
      darkSecondaryTextColor: Color(0xFF7DD3FC),
      lightBaseColor: Color(0xFFE0F2FE),
      lightAccentColor: Color(0xFF0284C7),
      lightTextColor: Color(0xFF0C4A6E),
      lightSecondaryTextColor: Color(0xFF0369A1),
    ),
    ThemePreset(
      name: "Emerald Forest",
      darkBaseColor: Color(0xFF064E3B),
      darkAccentColor: Color(0xFF34D399),
      darkTextColor: Color(0xFFECFDF5),
      darkSecondaryTextColor: Color(0xFFA7F3D0),
      lightBaseColor: Color(0xFFECFDF5),
      lightAccentColor: Color(0xFF059669),
      lightTextColor: Color(0xFF064E3B),
      lightSecondaryTextColor: Color(0xFF047857),
    ),
    ThemePreset(
      name: "Sunset Violet",
      darkBaseColor: Color(0xFF2E1065),
      darkAccentColor: Color(0xFFF43F5E),
      darkTextColor: Color(0xFFFAF5FF),
      darkSecondaryTextColor: Color(0xFFE9D5FF),
      lightBaseColor: Color(0xFFFAF5FF),
      lightAccentColor: Color(0xFFE11D48),
      lightTextColor: Color(0xFF3B0764),
      lightSecondaryTextColor: Color(0xFF6B21A8),
    ),
  ];

  // Light Mode Specific Presets
  static const List<ThemePreset> lightPresets = [
    ThemePreset(
      name: "Neumorphic Silver",
      darkBaseColor: Color(0xFF1E1E1E),
      darkAccentColor: Color(0xFF0D9488),
      darkTextColor: Color(0xFFE0E0E0),
      darkSecondaryTextColor: Color(0xFFA0A0A0),
      lightBaseColor: Color(0xFFE0E5EC),
      lightAccentColor: Color(0xFF0D9488),
      lightTextColor: Color(0xFF1E293B),
      lightSecondaryTextColor: Color(0xFF64748B),
    ),
    ThemePreset(
      name: "Clean Snow & Indigo",
      darkBaseColor: Color(0xFF1E1E2E),
      darkAccentColor: Color(0xFF6366F1),
      darkTextColor: Color(0xFFE2E8F0),
      darkSecondaryTextColor: Color(0xFF94A3B8),
      lightBaseColor: Color(0xFFF8FAFC),
      lightAccentColor: Color(0xFF4F46E5),
      lightTextColor: Color(0xFF0F172A),
      lightSecondaryTextColor: Color(0xFF475569),
    ),
    ThemePreset(
      name: "Warm Cream & Amber",
      darkBaseColor: Color(0xFF292524),
      darkAccentColor: Color(0xFFF59E0B),
      darkTextColor: Color(0xFFF5F5F4),
      darkSecondaryTextColor: Color(0xFFA8A29E),
      lightBaseColor: Color(0xFFF5F5F4),
      lightAccentColor: Color(0xFFD97706),
      lightTextColor: Color(0xFF1C1917),
      lightSecondaryTextColor: Color(0xFF57534E),
    ),
    ThemePreset(
      name: "Fresh Mint",
      darkBaseColor: Color(0xFF064E3B),
      darkAccentColor: Color(0xFF10B981),
      darkTextColor: Color(0xFFECFDF5),
      darkSecondaryTextColor: Color(0xFFA7F3D0),
      lightBaseColor: Color(0xFFE6F4EA),
      lightAccentColor: Color(0xFF059669),
      lightTextColor: Color(0xFF064E3B),
      lightSecondaryTextColor: Color(0xFF047857),
    ),
    ThemePreset(
      name: "Rose Quartz",
      darkBaseColor: Color(0xFF4C0519),
      darkAccentColor: Color(0xFFFB7185),
      darkTextColor: Color(0xFFFFF1F2),
      darkSecondaryTextColor: Color(0xFFFECDD3),
      lightBaseColor: Color(0xFFFFF1F2),
      lightAccentColor: Color(0xFFE11D48),
      lightTextColor: Color(0xFF881337),
      lightSecondaryTextColor: Color(0xFFBE123C),
    ),
  ];

  static List<ThemePreset> get currentPresets =>
      instance._themeMode == ThemeMode.dark ? darkPresets : lightPresets;

  void toggleThemeMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void selectPreset(int index) {
    if (_themeMode == ThemeMode.dark) {
      _selectedDarkPresetIndex = index;
      _customDarkAccentColor = null;
    } else {
      _selectedLightPresetIndex = index;
      _customLightAccentColor = null;
    }
    notifyListeners();
  }

  void updateCustomAccentColor(Color color) {
    if (_themeMode == ThemeMode.dark) {
      _customDarkAccentColor = color;
    } else {
      _customLightAccentColor = color;
    }
    notifyListeners();
  }

  void resetToPreset() {
    if (_themeMode == ThemeMode.dark) {
      _customDarkAccentColor = null;
    } else {
      _customLightAccentColor = null;
    }
    notifyListeners();
  }
}


import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  // ── SharedPreferences Keys ───────────────────────────────────────────────
  static const _kThemeMode = 'theme_mode'; // int: ThemeMode.values index
  static const _kDarkPreset = 'dark_preset_idx';
  static const _kLightPreset = 'light_preset_idx';
  static const _kDarkAccent = 'dark_accent_color'; // Color.value as int (ARGB)
  static const _kLightAccent = 'light_accent_color';
  static const _kDepth = 'neuro_depth';
  static const _kFontScale = 'font_scale';

  // ── State ────────────────────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.dark; // Default: Charcoal Slate (Dark)
  ThemeMode get themeMode => _themeMode;

  /// Dynamically evaluates whether dark mode is active (including resolving
  /// OS platform brightness when _themeMode == ThemeMode.system).
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      try {
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      } catch (_) {
        return true;
      }
    }
    return _themeMode == ThemeMode.dark;
  }

  Color? _customDarkAccentColor;
  Color? _customLightAccentColor;

  int _selectedDarkPresetIndex = 0;
  int _selectedLightPresetIndex = 0;

  double _neuDepth = 6.0;
  double _fontScale = 1.0;

  int get selectedDarkPresetIndex => _selectedDarkPresetIndex;
  int get selectedLightPresetIndex => _selectedLightPresetIndex;
  double get neuDepth => _neuDepth;
  double get fontScale => _fontScale;

  int get selectedPresetIndex =>
      isDarkMode ? _selectedDarkPresetIndex : _selectedLightPresetIndex;

  ThemePreset get currentPreset =>
      isDarkMode ? darkPresets[_selectedDarkPresetIndex] : lightPresets[_selectedLightPresetIndex];

  Color get currentBaseColor {
    return isDarkMode
        ? darkPresets[_selectedDarkPresetIndex].darkBaseColor
        : lightPresets[_selectedLightPresetIndex].lightBaseColor;
  }

  Color get currentAccentColor => accentColor;

  Color get accentColor {
    if (isDarkMode) {
      return _customDarkAccentColor ??
          darkPresets[_selectedDarkPresetIndex].darkAccentColor;
    } else {
      return _customLightAccentColor ??
          lightPresets[_selectedLightPresetIndex].lightAccentColor;
    }
  }

  Color get textColor {
    return isDarkMode
        ? darkPresets[_selectedDarkPresetIndex].darkTextColor
        : lightPresets[_selectedLightPresetIndex].lightTextColor;
  }

  Color get secondaryTextColor {
    return isDarkMode
        ? darkPresets[_selectedDarkPresetIndex].darkSecondaryTextColor
        : lightPresets[_selectedLightPresetIndex].lightSecondaryTextColor;
  }

  Color get shadowDarkColor {
    final base = currentBaseColor;
    if (isDarkMode) {
      final hsl = HSLColor.fromColor(base);
      return hsl
          .withLightness((hsl.lightness * 0.40).clamp(0.0, 1.0))
          .toColor();
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
    if (isDarkMode) {
      final hsl = HSLColor.fromColor(base);
      return hsl
          .withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0))
          .toColor();
    } else {
      return Colors.white.withValues(alpha: 0.95);
    }
  }

  // ── Dark Mode Presets (8 total) ──────────────────────────────────────────
  static const List<ThemePreset> darkPresets = [
    ThemePreset(
      name: 'Charcoal Slate',
      darkBaseColor: Color(0xFF1E2028),
      darkAccentColor: Color(0xFF00E5A0),
      darkTextColor: Color(0xFFE2E8F0),
      darkSecondaryTextColor: Color(0xFF94A3B8),
      lightBaseColor: Color(0xFFE0E5EC),
      lightAccentColor: Color(0xFF0D9488),
      lightTextColor: Color(0xFF0F172A),
      lightSecondaryTextColor: Color(0xFF475569),
    ),
    ThemePreset(
      name: 'Midnight Blue',
      darkBaseColor: Color(0xFF0A0F1E),
      darkAccentColor: Color(0xFF60A5FA),
      darkTextColor: Color(0xFFE0F2FE),
      darkSecondaryTextColor: Color(0xFF7DD3FC),
      lightBaseColor: Color(0xFFE0F2FE),
      lightAccentColor: Color(0xFF0284C7),
      lightTextColor: Color(0xFF0C4A6E),
      lightSecondaryTextColor: Color(0xFF0369A1),
    ),
    ThemePreset(
      name: 'Gunmetal & Amber',
      darkBaseColor: Color(0xFF1C1C1E),
      darkAccentColor: Color(0xFFF59E0B),
      darkTextColor: Color(0xFFF5F5F4),
      darkSecondaryTextColor: Color(0xFFA8A29E),
      lightBaseColor: Color(0xFFF5F5F4),
      lightAccentColor: Color(0xFFD97706),
      lightTextColor: Color(0xFF1C1917),
      lightSecondaryTextColor: Color(0xFF57534E),
    ),
    ThemePreset(
      name: 'Deep Plum',
      darkBaseColor: Color(0xFF1A0533),
      darkAccentColor: Color(0xFFC084FC),
      darkTextColor: Color(0xFFFAF5FF),
      darkSecondaryTextColor: Color(0xFFE9D5FF),
      lightBaseColor: Color(0xFFFAF5FF),
      lightAccentColor: Color(0xFF7C3AED),
      lightTextColor: Color(0xFF3B0764),
      lightSecondaryTextColor: Color(0xFF6B21A8),
    ),
    ThemePreset(
      name: 'Cyber Slate',
      darkBaseColor: Color(0xFF0F1117),
      darkAccentColor: Color(0xFFF97316),
      darkTextColor: Color(0xFFF8FAFC),
      darkSecondaryTextColor: Color(0xFF94A3B8),
      lightBaseColor: Color(0xFFF1F5F9),
      lightAccentColor: Color(0xFFEA580C),
      lightTextColor: Color(0xFF020617),
      lightSecondaryTextColor: Color(0xFF64748B),
    ),
    ThemePreset(
      name: 'Forest Night',
      darkBaseColor: Color(0xFF0D1F1A),
      darkAccentColor: Color(0xFF34D399),
      darkTextColor: Color(0xFFECFDF5),
      darkSecondaryTextColor: Color(0xFFA7F3D0),
      lightBaseColor: Color(0xFFECFDF5),
      lightAccentColor: Color(0xFF059669),
      lightTextColor: Color(0xFF064E3B),
      lightSecondaryTextColor: Color(0xFF047857),
    ),
    ThemePreset(
      name: 'Rose Noir',
      darkBaseColor: Color(0xFF1A0A10),
      darkAccentColor: Color(0xFFFB7185),
      darkTextColor: Color(0xFFFFF1F2),
      darkSecondaryTextColor: Color(0xFFFECDD3),
      lightBaseColor: Color(0xFFFFF1F2),
      lightAccentColor: Color(0xFFE11D48),
      lightTextColor: Color(0xFF881337),
      lightSecondaryTextColor: Color(0xFFBE123C),
    ),
    ThemePreset(
      name: 'Arctic Storm',
      darkBaseColor: Color(0xFF111827),
      darkAccentColor: Color(0xFF38BDF8),
      darkTextColor: Color(0xFFE0F2FE),
      darkSecondaryTextColor: Color(0xFF7DD3FC),
      lightBaseColor: Color(0xFFEDF4FB),
      lightAccentColor: Color(0xFF0284C7),
      lightTextColor: Color(0xFF0C4A6E),
      lightSecondaryTextColor: Color(0xFF0369A1),
    ),
  ];

  // ── Light Mode Presets (8 total) ─────────────────────────────────────────
  static const List<ThemePreset> lightPresets = [
    ThemePreset(
      name: 'Neumorphic Silver',
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
      name: 'Warm Linen',
      darkBaseColor: Color(0xFF292524),
      darkAccentColor: Color(0xFFF59E0B),
      darkTextColor: Color(0xFFF5F5F4),
      darkSecondaryTextColor: Color(0xFFA8A29E),
      lightBaseColor: Color(0xFFF5F0E8),
      lightAccentColor: Color(0xFFD97706),
      lightTextColor: Color(0xFF1C1917),
      lightSecondaryTextColor: Color(0xFF78716C),
    ),
    ThemePreset(
      name: 'Arctic White',
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
      name: 'Sage Green',
      darkBaseColor: Color(0xFF064E3B),
      darkAccentColor: Color(0xFF10B981),
      darkTextColor: Color(0xFFECFDF5),
      darkSecondaryTextColor: Color(0xFFA7F3D0),
      lightBaseColor: Color(0xFFEBF0E4),
      lightAccentColor: Color(0xFF16A34A),
      lightTextColor: Color(0xFF14532D),
      lightSecondaryTextColor: Color(0xFF166534),
    ),
    ThemePreset(
      name: 'Blush Cream',
      darkBaseColor: Color(0xFF4C0519),
      darkAccentColor: Color(0xFFFB7185),
      darkTextColor: Color(0xFFFFF1F2),
      darkSecondaryTextColor: Color(0xFFFECDD3),
      lightBaseColor: Color(0xFFFDF2F2),
      lightAccentColor: Color(0xFFE11D48),
      lightTextColor: Color(0xFF881337),
      lightSecondaryTextColor: Color(0xFFBE123C),
    ),
    ThemePreset(
      name: 'Sky Mist',
      darkBaseColor: Color(0xFF0C1A2E),
      darkAccentColor: Color(0xFF38BDF8),
      darkTextColor: Color(0xFFE0F2FE),
      darkSecondaryTextColor: Color(0xFF7DD3FC),
      lightBaseColor: Color(0xFFEDF4FB),
      lightAccentColor: Color(0xFF0284C7),
      lightTextColor: Color(0xFF0C4A6E),
      lightSecondaryTextColor: Color(0xFF0369A1),
    ),
    ThemePreset(
      name: 'Warm Sand',
      darkBaseColor: Color(0xFF292524),
      darkAccentColor: Color(0xFFD97706),
      darkTextColor: Color(0xFFFEF3C7),
      darkSecondaryTextColor: Color(0xFFFDE68A),
      lightBaseColor: Color(0xFFFAF3E0),
      lightAccentColor: Color(0xFFB45309),
      lightTextColor: Color(0xFF1C1917),
      lightSecondaryTextColor: Color(0xFF78716C),
    ),
    ThemePreset(
      name: 'Lilac Haze',
      darkBaseColor: Color(0xFF2E1065),
      darkAccentColor: Color(0xFFA855F7),
      darkTextColor: Color(0xFFFAF5FF),
      darkSecondaryTextColor: Color(0xFFE9D5FF),
      lightBaseColor: Color(0xFFF3F0FA),
      lightAccentColor: Color(0xFF7C3AED),
      lightTextColor: Color(0xFF3B0764),
      lightSecondaryTextColor: Color(0xFF6B21A8),
    ),
  ];

  static List<ThemePreset> get currentPresets =>
      instance._themeMode == ThemeMode.dark ? darkPresets : lightPresets;

  // ── Persistence ──────────────────────────────────────────────────────────

  /// Called once in main() before runApp. Restores all persisted settings.
  /// Default themeMode = ThemeMode.light (index 1 in ThemeMode.values).
  Future<void> loadPersistedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // ThemeMode.values = [system(0), light(1), dark(2)] — default 2 = dark (Charcoal Slate)
    final modeIdx = prefs.getInt(_kThemeMode) ?? 2;
    _themeMode =
        ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)];
    _selectedDarkPresetIndex =
        (prefs.getInt(_kDarkPreset) ?? 0).clamp(0, darkPresets.length - 1);
    _selectedLightPresetIndex =
        (prefs.getInt(_kLightPreset) ?? 0).clamp(0, lightPresets.length - 1);
    final da = prefs.getInt(_kDarkAccent);
    final la = prefs.getInt(_kLightAccent);
    if (da != null) _customDarkAccentColor = Color(da);
    if (la != null) _customLightAccentColor = Color(la);
    _neuDepth = (prefs.getDouble(_kDepth) ?? 6.0).clamp(3.0, 10.0);
    _fontScale = (prefs.getDouble(_kFontScale) ?? 1.0).clamp(0.80, 1.40);
    notifyListeners();
  }

  /// Fire-and-forget write. All setters call this after mutating state.
  void _persist() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_kThemeMode, ThemeMode.values.indexOf(_themeMode));
      prefs.setInt(_kDarkPreset, _selectedDarkPresetIndex);
      prefs.setInt(_kLightPreset, _selectedLightPresetIndex);
      if (_customDarkAccentColor != null)
        prefs.setInt(_kDarkAccent, _customDarkAccentColor!.toARGB32());
      if (_customLightAccentColor != null)
        prefs.setInt(_kLightAccent, _customLightAccentColor!.toARGB32());
      prefs.setDouble(_kDepth, _neuDepth);
      prefs.setDouble(_kFontScale, _fontScale);
    });
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void toggleThemeMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _persist();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _persist();
    notifyListeners();
  }

  void selectPreset(int index) {
    if (isDarkMode) {
      _selectedDarkPresetIndex = index.clamp(0, darkPresets.length - 1);
      _customDarkAccentColor = null;
    } else {
      _selectedLightPresetIndex = index.clamp(0, lightPresets.length - 1);
      _customLightAccentColor = null;
    }
    _persist();
    notifyListeners();
  }

  void updateCustomAccentColor(Color color) {
    if (isDarkMode) {
      _customDarkAccentColor = color;
    } else {
      _customLightAccentColor = color;
    }
    _persist();
    notifyListeners();
  }

  void resetToPreset() {
    if (isDarkMode) {
      _customDarkAccentColor = null;
    } else {
      _customLightAccentColor = null;
    }
    _persist();
    notifyListeners();
  }

  void setDepth(double depth) {
    _neuDepth = depth.clamp(3.0, 10.0);
    _persist();
    notifyListeners();
  }

  void setFontScale(double scale) {
    _fontScale = scale.clamp(0.80, 1.40);
    _persist();
    notifyListeners();
  }
}

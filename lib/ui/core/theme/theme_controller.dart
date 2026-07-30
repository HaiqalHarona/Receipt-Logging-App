import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'app_theme.dart';

/// Theme Preset Definitions
class ThemePreset {
  final String name;
  final Color baseColor;
  final Color accentColor;
  final Color textColor;
  final Color secondaryTextColor;

  const ThemePreset({
    required this.name,
    required this.baseColor,
    required this.accentColor,
    required this.textColor,
    required this.secondaryTextColor,
  });
}

class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // Custom Colors
  Color _customAccentColor = const Color(0xFF00FF85);
  Color _customTextColor = const Color(0xFFE0E0E0);
  bool _useCustomColors = false;

  Color get accentColor {
    if (_themeMode == ThemeMode.light) {
      return _useCustomColors ? _customAccentColor : AppTheme.lightAccentTeal;
    }
    return _useCustomColors ? _customAccentColor : currentPreset.accentColor;
  }

  Color get textColor {
    if (_themeMode == ThemeMode.light) {
      if (_useCustomColors && _customTextColor != const Color(0xFFFFFFFF) && _customTextColor != const Color(0xFFE0E0E0)) {
        return _customTextColor;
      }
      return AppTheme.lightTextPrimary;
    }
    return _useCustomColors ? _customTextColor : currentPreset.textColor;
  }

  bool get useCustomColors => _useCustomColors;
  Color get customAccentColor => _customAccentColor;
  Color get customTextColor => _customTextColor;



  // Pre-configured Color Presets
  static const List<ThemePreset> presets = [
    ThemePreset(
      name: "Classic Charcoal",
      baseColor: Color(0xFF1E1E1E),
      accentColor: Color(0xFF00FF85),
      textColor: Color(0xFFE0E0E0),
      secondaryTextColor: Color(0xFFA0A0A0),
    ),
    ThemePreset(
      name: "Neon Cyberpunk",
      baseColor: Color(0xFF0F0F23),
      accentColor: Color(0xFFF97316),
      textColor: Color(0xFFF8FAFC),
      secondaryTextColor: Color(0xFF94A3B8),
    ),
    ThemePreset(
      name: "Deep Ocean",
      baseColor: Color(0xFF0D1B2A),
      accentColor: Color(0xFF38BDF8),
      textColor: Color(0xFFE0F2FE),
      secondaryTextColor: Color(0xFF7DD3FC),
    ),
    ThemePreset(
      name: "Emerald Forest",
      baseColor: Color(0xFF064E3B),
      accentColor: Color(0xFF34D399),
      textColor: Color(0xFFECFDF5),
      secondaryTextColor: Color(0xFFA7F3D0),
    ),
    ThemePreset(
      name: "Sunset Violet",
      baseColor: Color(0xFF2E1065),
      accentColor: Color(0xFFF43F5E),
      textColor: Color(0xFFFAF5FF),
      secondaryTextColor: Color(0xFFE9D5FF),
    ),
  ];

  int _selectedPresetIndex = 0;
  int get selectedPresetIndex => _selectedPresetIndex;
  ThemePreset get currentPreset => presets[_selectedPresetIndex];

  void toggleThemeMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void selectPreset(int index) {
    _selectedPresetIndex = index;
    _useCustomColors = false;
    _customAccentColor = presets[index].accentColor;
    _customTextColor = presets[index].textColor;
    notifyListeners();
  }

  void updateCustomAccentColor(Color color) {
    _customAccentColor = color;
    _useCustomColors = true;
    notifyListeners();
  }

  void updateCustomTextColor(Color color) {
    _customTextColor = color;
    _useCustomColors = true;
    notifyListeners();
  }

  void resetToPreset() {
    _useCustomColors = false;
    notifyListeners();
  }
}

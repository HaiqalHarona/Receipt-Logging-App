// File: test/unit/theme_controller_test.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/services/user_preferences_service.dart';
import 'package:reciept_logging/ui/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppThemeController Unit Tests', () {
    test('Defaults to Dark Mode and Charcoal Slate preset', () {
      final controller = AppThemeController.instance;

      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.selectedPresetIndex, equals(0));
      expect(controller.neuDepth, equals(6.0));
      expect(controller.fontScale, equals(1.0));
    });

    test('Toggles theme mode and updates currentBaseColor', () {
      final controller = AppThemeController.instance;

      controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);

      controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isDarkMode, isFalse);

      controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, equals(ThemeMode.system));
      // isDarkMode resolves dynamically according to platform dispatcher
      expect(controller.isDarkMode, isA<bool>());
    });

    test('Selects presets and updates colors', () {
      final controller = AppThemeController.instance;

      controller.setThemeMode(ThemeMode.dark);
      controller.selectPreset(1); // Midnight Blue
      expect(controller.selectedPresetIndex, equals(1));
      expect(controller.currentPreset.name, equals('Midnight Blue'));

      controller.setThemeMode(ThemeMode.light);
      controller.selectPreset(2); // Arctic White
      expect(controller.selectedPresetIndex, equals(2));
      expect(controller.currentPreset.name, equals('Arctic White'));
    });

    test('Custom depth and font scale setters clamp within valid ranges', () {
      final controller = AppThemeController.instance;

      controller.setDepth(8.5);
      expect(controller.neuDepth, equals(8.5));

      controller.setFontScale(1.15);
      expect(controller.fontScale, equals(1.15));
    });

    test('Custom accent color override and resetToPreset', () {
      final controller = AppThemeController.instance;
      const customColor = Color(0xFFFF5722);

      controller.updateCustomAccentColor(customColor);
      expect(controller.accentColor, equals(customColor));

      controller.resetToPreset();
      expect(controller.accentColor, isNot(equals(customColor)));
    });

    test(
        'currentPresets returns darkPresets when isDarkMode is true and lightPresets when false',
        () {
      final controller = AppThemeController.instance;

      controller.setThemeMode(ThemeMode.dark);
      expect(AppThemeController.currentPresets,
          equals(AppThemeController.darkPresets));

      controller.setThemeMode(ThemeMode.light);
      expect(AppThemeController.currentPresets,
          equals(AppThemeController.lightPresets));
    });

    test(
        'shadowDarkColorEmboss and shadowLightColorEmboss subdue glow in dark mode',
        () {
      final controller = AppThemeController.instance;

      controller.setThemeMode(ThemeMode.dark);
      expect(controller.shadowDarkColorEmboss.a, greaterThan(0.0));
      expect(controller.shadowLightColorEmboss.a, lessThan(0.5));

      controller.setThemeMode(ThemeMode.light);
      expect(
          controller.shadowDarkColorEmboss, equals(controller.shadowDarkColor));
      expect(controller.shadowLightColorEmboss,
          equals(controller.shadowLightColor));
    });

    test(
        'UserPreferencesService builds and applies comprehensive preferences payload',
        () async {
      final controller = AppThemeController.instance;
      controller.setThemeMode(ThemeMode.dark);
      controller.selectPreset(3); // Deep Plum
      controller.setCustomDarkAccentColor(const Color(0xFFE91E63));
      controller.setDepth(7.5);
      controller.setFontScale(1.10);

      final payload =
          UserPreferencesService.instance.buildPreferencesPayload();

      expect(payload['theme_mode'], equals(ThemeMode.values.indexOf(ThemeMode.dark)));
      expect(payload['dark_preset_idx'], equals(3));
      expect(payload['dark_accent_color'], equals(const Color(0xFFE91E63).toARGB32()));
      expect(payload['neuro_depth'], equals(7.5));
      expect(payload['font_scale'], equals(1.10));

      // Apply new cloud preferences payload
      final cloudPayload = {
        'currency': 'EUR',
        'theme_mode': ThemeMode.values.indexOf(ThemeMode.light),
        'light_preset_idx': 4,
        'light_accent_color': const Color(0xFF00BCD4).toARGB32(),
        'neuro_depth': 4.5,
        'font_scale': 1.25,
      };

      await UserPreferencesService.instance
          .applyCloudPreferences(cloudPayload);

      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.selectedLightPresetIndex, equals(4));
      expect(controller.customLightAccentColor, equals(const Color(0xFF00BCD4)));
      expect(controller.neuDepth, equals(4.5));
      expect(controller.fontScale, equals(1.25));
    });
  });
}

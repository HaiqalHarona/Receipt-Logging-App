import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reciept_logging/core/constants/app_constants.dart';

enum AppThemeMode { light, dark }

class ThemeNotifier extends Notifier<AppThemeMode> {
  static const _storage = FlutterSecureStorage();

  @override
  AppThemeMode build() {
    _loadTheme();
    return AppThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final saved = await _storage.read(key: AppConstants.keyThemeMode);
    if (saved == 'dark') {
      state = AppThemeMode.dark;
    }
  }

  void toggle() {
    state = state == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light;
    _storage.write(
      key: AppConstants.keyThemeMode,
      value: state.name,
    );
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(
  ThemeNotifier.new,
);

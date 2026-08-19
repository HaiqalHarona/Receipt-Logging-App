// lib/cloud/services/user_preferences_service.dart
//
// Centralized User Preferences Synchronization Service.
//
// Responsibilities:
//   1. Collects theme appearance and currency preferences from local controllers.
//   2. Debounces updates (800ms) and pushes to Supabase users.preferences via PATCH /user/me when logged in.
//   3. Restores cloud preferences on login or session load without causing infinite sync loops.

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../services/app_logger_service.dart';
import '../../services/currency_service.dart';
import '../../ui/core/theme/theme_controller.dart';
import '../api/backend_api_client.dart';
import 'auth_service.dart';

class UserPreferencesService {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();

  Timer? _debounceTimer;
  bool _isApplyingCloudPreferences = false;

  /// Schedules a debounced push of local preferences to the backend.
  ///
  /// Safe to call on every slider move, theme toggle, or currency change.
  /// If the user is a guest (not logged in), this is a no-op.
  void scheduleSync() {
    if (_isApplyingCloudPreferences) return;
    if (!AuthService.instance.isLoggedIn) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      syncNow();
    });
  }

  /// Immediately pushes the current local preferences to the cloud.
  Future<void> syncNow() async {
    final username = AuthService.instance.currentUsername;
    final userToken = AuthService.instance.currentUserToken;

    if (!AuthService.instance.isLoggedIn || username == null || userToken == null) {
      return;
    }

    final payload = buildPreferencesPayload();
    try {
      AppLogger.info('UserPreferencesService', 'Syncing preferences to cloud: $payload');
      await BackendApiClient.instance.updateUserPreferences(
        username: username,
        userToken: userToken,
        preferences: payload,
      );
      AppLogger.info('UserPreferencesService', 'Preferences successfully synced to cloud.');
    } catch (e, st) {
      // Offline-safe: gracefully log without crashing or interrupting UI
      AppLogger.warning('UserPreferencesService', 'Deferred preferences cloud sync: $e', st);
    }
  }

  /// Builds a JSON-serializable Map of current UI & spending preferences.
  Map<String, dynamic> buildPreferencesPayload() {
    final theme = AppThemeController.instance;
    return {
      'currency': CurrencyService.instance.currentCurrency,
      'theme_mode': ThemeMode.values.indexOf(theme.themeMode),
      'dark_preset_idx': theme.selectedDarkPresetIndex,
      'light_preset_idx': theme.selectedLightPresetIndex,
      'neuro_depth': theme.neuDepth,
      'font_scale': theme.fontScale,
    };
  }

  /// Applies a preferences JSON payload from the cloud to local controllers.
  ///
  /// Sets [_isApplyingCloudPreferences] = true to suppress feedback sync loops.
  Future<void> applyCloudPreferences(Map<String, dynamic> preferences) async {
    if (preferences.isEmpty) return;

    _isApplyingCloudPreferences = true;
    try {
      AppLogger.info('UserPreferencesService', 'Applying cloud preferences: $preferences');

      // 1. Currency
      final currency = preferences['currency'] as String?;
      if (currency != null && currency.isNotEmpty) {
        CurrencyService.instance.setCurrency(currency);
      }

      // 2. Theme Mode
      final theme = AppThemeController.instance;
      final modeIdx = preferences['theme_mode'] as int?;
      if (modeIdx != null && modeIdx >= 0 && modeIdx < ThemeMode.values.length) {
        theme.setThemeMode(ThemeMode.values[modeIdx]);
      }

      // 3. Presets
      final darkIdx = preferences['dark_preset_idx'] as int?;
      if (darkIdx != null) {
        if (theme.isDarkMode) {
          theme.selectPreset(darkIdx);
        }
      }
      final lightIdx = preferences['light_preset_idx'] as int?;
      if (lightIdx != null) {
        if (!theme.isDarkMode) {
          theme.selectPreset(lightIdx);
        }
      }

      // 4. Depth & Font Scale
      final depth = (preferences['neuro_depth'] as num?)?.toDouble();
      if (depth != null) {
        theme.setDepth(depth);
      }
      final fontScale = (preferences['font_scale'] as num?)?.toDouble();
      if (fontScale != null) {
        theme.setFontScale(fontScale);
      }
    } catch (e, st) {
      AppLogger.error('UserPreferencesService', 'Failed to apply cloud preferences', e, st);
    } finally {
      _isApplyingCloudPreferences = false;
    }
  }
}

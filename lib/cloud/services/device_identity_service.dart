// lib/cloud/services/device_identity_service.dart
//
// Persistent Device Identity Service for non-signed in and signed in workflows.
//
// Security & Persistence Rules:
// 1. `deviceId` is generated ONCE on first boot (e.g. `dev_<uuid>`) and saved to
//    SharedPreferences. It remains identical across all future runtimes & restarts.
// 2. `deviceToken` is generated ONCE prior to device registration (e.g. `token_<uuid>`).
//    Stored locally on device and sent in X-Device-Token for API requests.
// 3. Registers device with backend via `POST /api/v1/devices/register` on boot.

import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../services/app_logger_service.dart';
import '../api/backend_api_client.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const String _keyDeviceId = 'app_device_id';
  static const String _keyDeviceToken = 'app_device_token';
  static const String _keyTrialUsed = 'app_has_device_used_trial';

  FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Allows unit tests to provide an in-memory secure storage mock.
  void setSecureStorageForTesting(FlutterSecureStorage storage) {
    _secureStorage = storage;
  }

  String? _deviceId;
  String? _deviceToken;
  bool _hasDeviceUsedTrial = false;
  bool _isInitialized = false;

  /// Returns the persistent hardware device ID.
  String get deviceId => _deviceId ?? 'flutter-device-id-fallback';

  /// Returns the persistent hardware device token.
  String get deviceToken => _deviceToken ?? '';

  /// Returns whether this hardware device has already redeemed a 14-day trial.
  bool get hasDeviceUsedTrial => _hasDeviceUsedTrial;

  /// Returns whether device identity has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes device identity:
  /// 1. Reads `deviceId`, `deviceToken`, and `hasDeviceUsedTrial` from FlutterSecureStorage
  ///    (iOS Keychain / Android Keystore, persisting across app reinstalls) or SharedPreferences.
  /// 2. Generates and securely persists them ONCE if missing.
  /// 3. Registers or refreshes the device with the backend (POST /api/v1/devices/register) asynchronously.
  Future<void> init(BackendApiClient apiClient) async {
    if (_isInitialized) return;

    try {
      // Check if fixed development device ID is explicitly enabled via .env
      final isFixedDevMode = dotenv.isInitialized &&
          dotenv.maybeGet('USE_FIXED_DEVICE_ID') == 'true';

      if (isFixedDevMode) {
        _deviceId =
            dotenv.maybeGet('FIXED_DEVICE_ID') ?? 'dev_fixed_debug_device_001';
        _deviceToken = dotenv.maybeGet('FIXED_DEVICE_TOKEN') ??
            'token_fixed_debug_secret_001';
        AppLogger.info('DeviceIdentity',
            'Loaded fixed development device identity from .env: $_deviceId');
      } else {
        final prefs = await SharedPreferences.getInstance();
        const uuid = Uuid();

        // 1. Check secure storage first (preserves identity across uninstalls on iOS & Keystore)
        String? secureDeviceId;
        String? secureDeviceToken;
        String? secureTrialUsed;
        try {
          secureDeviceId = await _secureStorage.read(key: _keyDeviceId);
          secureDeviceToken = await _secureStorage.read(key: _keyDeviceToken);
          secureTrialUsed = await _secureStorage.read(key: _keyTrialUsed);
        } catch (e) {
          AppLogger.warning('DeviceIdentity', 'SecureStorage read error: $e');
        }

        final prefsDeviceId = prefs.getString(_keyDeviceId);
        final prefsDeviceToken = prefs.getString(_keyDeviceToken);
        final prefsTrialUsed = prefs.getBool(_keyTrialUsed) ?? false;

        // Resolve deviceId
        _deviceId = secureDeviceId ?? prefsDeviceId;
        if (_deviceId == null || _deviceId!.isEmpty) {
          _deviceId = 'dev_${uuid.v4()}';
          AppLogger.info('DeviceIdentity',
              'Generated new persistent deviceId: $_deviceId');
        } else {
          AppLogger.info('DeviceIdentity',
              'Loaded existing persistent deviceId: $_deviceId');
        }

        // Resolve deviceToken
        _deviceToken = secureDeviceToken ?? prefsDeviceToken;
        if (_deviceToken == null || _deviceToken!.isEmpty) {
          _deviceToken = 'token_${uuid.v4()}';
          AppLogger.info('DeviceIdentity', 'Generated new deviceToken');
        }

        // Resolve trial used flag
        _hasDeviceUsedTrial = secureTrialUsed == 'true' || prefsTrialUsed;

        // Persist to both SecureStorage and SharedPreferences for dual-layer durability
        try {
          await prefs.setString(_keyDeviceId, _deviceId!);
          await prefs.setString(_keyDeviceToken, _deviceToken!);
          await prefs.setBool(_keyTrialUsed, _hasDeviceUsedTrial);

          await _secureStorage.write(key: _keyDeviceId, value: _deviceId);
          await _secureStorage.write(key: _keyDeviceToken, value: _deviceToken);
          if (_hasDeviceUsedTrial) {
            await _secureStorage.write(key: _keyTrialUsed, value: 'true');
          }
        } catch (e) {
          AppLogger.warning('DeviceIdentity', 'Error saving persistent credentials: $e');
        }
      }

      _isInitialized = true;

      // Register or refresh device identity with the backend asynchronously (non-blocking)
      unawaited(_registerDeviceAsync(apiClient));
    } catch (e, st) {
      AppLogger.error('DeviceIdentity', 'Initialization error', e, st);
    }
  }

  Future<void> _registerDeviceAsync(BackendApiClient apiClient) async {
    try {
      await apiClient.registerDevice(
        deviceId: _deviceId!,
        deviceToken: _deviceToken!,
      );
      AppLogger.info(
          'DeviceIdentity', 'Device registered with backend successfully');
    } catch (e) {
      AppLogger.warning(
          'DeviceIdentity', 'Backend device registration deferred', e);
    }
  }

  /// Forces a fresh registration with explicit credentials (used in dev tests).
  void setCredentials({required String deviceId, required String deviceToken}) {
    _deviceId = deviceId;
    _deviceToken = deviceToken;
    _isInitialized = true;
  }

  /// Marks this physical hardware device as having redeemed a 14-day trial.
  /// Persisted in SecureStorage (Keychain/Keystore) and SharedPreferences.
  Future<void> markTrialUsed() async {
    _hasDeviceUsedTrial = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTrialUsed, true);
      await _secureStorage.write(key: _keyTrialUsed, value: 'true');
      AppLogger.info('DeviceIdentity', 'Device marked as trial used: $_deviceId');
    } catch (e) {
      AppLogger.warning('DeviceIdentity', 'Error saving trial used flag: $e');
    }
  }

  /// Queries the backend GET /api/v1/devices/{deviceId}/trial-status to determine
  /// if this device is eligible to display and redeem the 14-day trial.
  Future<bool> checkTrialEligibility(BackendApiClient apiClient) async {
    if (_hasDeviceUsedTrial) {
      return false;
    }
    try {
      final trialUsed = await apiClient.checkDeviceTrialStatus(deviceId);
      if (trialUsed) {
        await markTrialUsed();
        return false;
      }
      return true;
    } catch (e) {
      AppLogger.warning('DeviceIdentity', 'Failed to check trial eligibility: $e');
      return !_hasDeviceUsedTrial;
    }
  }

  /// Keeps the persistent hardware `deviceId` intact, regenerates a fresh secret `deviceToken`,
  /// authenticates with the current `deviceToken` via `POST /api/v1/devices/rotate-token`,
  /// and saves the new `deviceToken` locally.
  /// Called upon user logout to enter Guest Mode while maintaining hardware device continuity.
  Future<void> rotateDeviceToken(BackendApiClient apiClient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const uuid = Uuid();

      // Keep existing persistent deviceId if present, else fallback/generate
      _deviceId ??= prefs.getString(_keyDeviceId);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = 'dev_${uuid.v4()}';
        await prefs.setString(_keyDeviceId, _deviceId!);
        await _secureStorage.write(key: _keyDeviceId, value: _deviceId);
      }

      final oldToken = _deviceToken ?? prefs.getString(_keyDeviceToken) ?? '';
      final newToken = 'token_${uuid.v4()}';

      if (oldToken.isNotEmpty) {
        await apiClient.rotateDeviceToken(
          deviceName: _deviceId!,
          oldDeviceToken: oldToken,
          newDeviceToken: newToken,
        );
        AppLogger.info(
            'DeviceIdentity', 'Rotated device token with backend successfully');
      } else {
        await apiClient.registerDevice(
          deviceId: _deviceId!,
          deviceToken: newToken,
        );
        AppLogger.info(
            'DeviceIdentity', 'Initial device token registered with backend');
      }

      _deviceToken = newToken;
      await prefs.setString(_keyDeviceToken, _deviceToken!);
      await _secureStorage.write(key: _keyDeviceToken, value: _deviceToken);
      AppLogger.info('DeviceIdentity',
          'Saved new deviceToken locally for deviceId: $_deviceId');
    } catch (e, st) {
      AppLogger.error('DeviceIdentity', 'Token rotation error', e, st);
    }
  }

  /// Alias for backward compatibility.
  Future<void> resetToNewGuestDevice(BackendApiClient apiClient) =>
      rotateDeviceToken(apiClient);
}

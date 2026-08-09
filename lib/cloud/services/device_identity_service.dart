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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../api/backend_api_client.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  static const String _keyDeviceId = 'app_device_id';
  static const String _keyDeviceToken = 'app_device_token';

  String? _deviceId;
  String? _deviceToken;
  bool _isInitialized = false;

  /// Returns the persistent hardware device ID.
  String get deviceId => _deviceId ?? 'flutter-device-id-fallback';

  /// Returns the persistent hardware device token.
  String get deviceToken => _deviceToken ?? '';

  /// Returns whether device identity has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes device identity:
  /// 1. Reads `deviceId` and `deviceToken` from SharedPreferences.
  /// 2. Generates and saves them ONCE if missing.
  /// 3. Registers or refreshes the device with the backend (POST /api/v1/devices/register).
  Future<void> init(BackendApiClient apiClient) async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      const uuid = Uuid();

      // Read or generate persistent deviceId
      _deviceId = prefs.getString(_keyDeviceId);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = 'dev_${uuid.v4()}';
        await prefs.setString(_keyDeviceId, _deviceId!);
        debugPrint('🔑 [DeviceIdentity] Generated new persistent deviceId: $_deviceId');
      } else {
        debugPrint('🔑 [DeviceIdentity] Loaded existing persistent deviceId: $_deviceId');
      }

      // Read or generate persistent deviceToken
      _deviceToken = prefs.getString(_keyDeviceToken);
      if (_deviceToken == null || _deviceToken!.isEmpty) {
        _deviceToken = 'token_${uuid.v4()}';
        await prefs.setString(_keyDeviceToken, _deviceToken!);
        debugPrint('🔐 [DeviceIdentity] Generated new deviceToken');
      }

      // Register or refresh device identity with the backend
      try {
        await apiClient.registerDevice(
          deviceId: _deviceId!,
          deviceToken: _deviceToken!,
        );
        debugPrint('🚀 [DeviceIdentity] Device registered with backend successfully');
      } catch (e) {
        debugPrint('⚠️ [DeviceIdentity] Backend device registration deferred: $e');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [DeviceIdentity] Initialization error: $e');
    }
  }

  /// Forces a fresh registration with explicit credentials (used in dev tests).
  void setCredentials({required String deviceId, required String deviceToken}) {
    _deviceId = deviceId;
    _deviceToken = deviceToken;
    _isInitialized = true;
  }
}

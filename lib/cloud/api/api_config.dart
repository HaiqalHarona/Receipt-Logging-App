/// API configuration for Receipt Logger backend (FastAPI @ port 8085).
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/device_identity_service.dart';

class ApiConfig {
  ApiConfig._();

  /// Base URL for backend read dynamically from .env.
  /// Defaults to localhost:8085 for Desktop/Web/iOS, with 10.0.2.2 for Android emulator.
  static String get baseUrl {
    final configured = dotenv.get('API_BASE_URL', fallback: 'http://localhost:8085/api/v1');
    // if (defaultTargetPlatform == TargetPlatform.android && configured.contains('localhost')) {
    //   return configured.replaceAll('localhost', '10.0.2.2');
    // }
    return configured;
  }

  /// Supabase Project URL read dynamically from .env
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');

  /// Supabase Key read dynamically from .env
  static String get supabaseKey => dotenv.get('SUPABASE_KEY', fallback: '');

  /// Gemini API Key read dynamically from .env
  static String get geminiApiKey => dotenv.get('GEMINI_API_KEY', fallback: '');

  /// Persistent hardware device ID powered by DeviceIdentityService.
  static String get deviceId => DeviceIdentityService.instance.deviceId;

  /// Persistent device auth token powered by DeviceIdentityService.
  static String get deviceToken => DeviceIdentityService.instance.deviceToken;

  /// Default request timeout — Gemini vision can take ~3s.
  static const Duration timeout = Duration(seconds: 40);

  /// Builds device-scoped headers (GET /devices/me, DELETE /devices/me).
  static Map<String, String> buildDeviceHeaders({
    required String deviceName,
    required String deviceToken,
  }) {
    return {
      'Content-Type': 'application/json',
      'X-Device-Name': deviceName,
      'X-Device-Token': deviceToken,
    };
  }

  /// Builds user-scoped headers (GET/PATCH/DELETE /user/me, /receipts/*, /chat/*).
  static Map<String, String> buildUserHeaders({
    required String username,
    required String userToken,
  }) {
    return {
      'Content-Type': 'application/json',
      'X-User-Name': username,
      'X-User-Token': userToken,
    };
  }

  /// Builds 4-header link bridge headers required by POST /devices/link.
  static Map<String, String> buildLinkBridgeHeaders({
    required String deviceName,
    required String deviceToken,
    required String username,
    required String userToken,
  }) {
    return {
      'Content-Type': 'application/json',
      'X-Device-Name': deviceName,
      'X-Device-Token': deviceToken,
      'X-User-Name': username,
      'X-User-Token': userToken,
    };
  }

  /// Builds scoped headers required by /scan/* and POST /chat/query.
  static Map<String, String> buildScanHeaders({
    required String requestType,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
  }) {
    final cleanType = requestType.trim().toLowerCase();
    if (cleanType == 'guest') {
      return {
        'Content-Type': 'application/json',
        'X-Request-Type': 'guest',
        'X-Device-Name': deviceName ?? '',
        'X-Device-Token': deviceToken ?? '',
      };
    } else {
      return {
        'Content-Type': 'application/json',
        'X-Request-Type': 'user',
        'X-User-Name': username ?? '',
        'X-User-Token': userToken ?? '',
      };
    }
  }

  /// Legacy helper retained for backward compatibility.
  static Map<String, String> buildHeaders({
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) {
    return {
      'Content-Type': 'application/json',
      'X-Device-Name': deviceId,
      'X-Device-Token': deviceToken,
      if (userId != null && userId.isNotEmpty) 'X-User-Name': userId,
    };
  }
}

/// API configuration for Receipt Logger backend (FastAPI @ port 8085).
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import '../services/device_identity_service.dart';

class ApiConfig {
  static String _env(String key, [String fallback = '']) {
    if (!dotenv.isInitialized) return fallback;
    return dotenv.maybeGet(key) ?? fallback;
  }

  /// Application display name read dynamically from environment or .env
  static String get appName =>
      const String.fromEnvironment('APP_NAME').isNotEmpty
          ? const String.fromEnvironment('APP_NAME')
          : _env('APP_NAME', 'Receipt Logger');

  /// Current environment stage (alpha, staging, beta, production). Defaults to alpha.
  static String get appEnv => _env('APP_ENV', 'alpha');

  /// Semantic version string (MAJOR.MINOR.PATCH), defaults to 1.0.1.
  static String get appVersion => _env('APP_VERSION', '1.0.1');

  /// Build / revision number, defaults to 1.
  static int get appBuildNumber =>
      int.tryParse(_env('APP_BUILD_NUMBER', '1')) ?? 1;

  /// Formatted display version string (e.g. 1.0.1.0.1).
  static String get appVersionDisplay =>
      _env('APP_VERSION_DISPLAY', '$appVersion.0.$appBuildNumber');

  /// Staging manifest URL for Tailscale private network updates.
  static String get stagingManifestUrl {
    final direct =
        const String.fromEnvironment('STAGING_MANIFEST_URL').isNotEmpty
            ? const String.fromEnvironment('STAGING_MANIFEST_URL')
            : _env('STAGING_MANIFEST_URL', '');
    if (direct.isNotEmpty) return direct;

    // Fallback derivation from baseUrl host (e.g. port 9090 on same host):
    try {
      final uri = Uri.parse(baseUrl);
      if (uri.host.isNotEmpty &&
          uri.host != 'localhost' &&
          uri.host != '127.0.0.1' &&
          uri.host != '10.0.2.2') {
        return '${uri.scheme}://${uri.host}:9090/staging_manifest.json';
      }
    } catch (_) {}

    return '';
  }

  /// Helper boolean checks for environment mode
  static bool get isAlpha => appEnv.toLowerCase() == 'alpha';
  static bool get isStaging =>
      appEnv.toLowerCase() == 'staging' ||
      appEnv.toLowerCase() == 'alpha' ||
      appEnv.toLowerCase() == 'beta';
  static bool get isProduction =>
      appEnv.toLowerCase() == 'production' ||
      appEnv.toLowerCase() == 'prod' ||
      appEnv.toLowerCase() == 'release';

  /// Base URL for backend read dynamically from environment or .env.
  /// Defaults to localhost:8085 for Desktop/Web/iOS, with 10.0.2.2 for Android emulator.
  static String get baseUrl =>
      const String.fromEnvironment('API_BASE_URL').isNotEmpty
          ? const String.fromEnvironment('API_BASE_URL')
          : _env('API_BASE_URL', 'http://localhost:8085/api/v1');

  /// Supabase Project URL read dynamically from environment or .env
  static String get supabaseUrl =>
      const String.fromEnvironment('SUPABASE_URL').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : _env('SUPABASE_URL', '');

  /// Supabase Key read dynamically from environment or .env
  static String get supabaseKey =>
      const String.fromEnvironment('SUPABASE_KEY').isNotEmpty
          ? const String.fromEnvironment('SUPABASE_KEY')
          : _env('SUPABASE_KEY', '');

  /// AI API Key read dynamically from environment or .env (optional fallback)
  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
          ? const String.fromEnvironment('GEMINI_API_KEY')
          : _env('GEMINI_API_KEY', '');

  /// Persistent hardware device ID powered by DeviceIdentityService.
  static String get deviceId => DeviceIdentityService.instance.deviceId;

  /// Persistent device auth token powered by DeviceIdentityService.
  static String get deviceToken => DeviceIdentityService.instance.deviceToken;

  /// Default request timeout — AI vision parsing can take ~3s.
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
    String? username,
    String? userToken,
    String? accessToken,
  }) {
    final token = accessToken ?? AuthService.instance.accessToken;
    final user = username ?? AuthService.instance.currentUsername;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (user != null && user.isNotEmpty) {
      headers['X-User-Name'] = user;
    }
    if (userToken != null && userToken.isNotEmpty) {
      headers['X-User-Token'] = userToken;
    }
    return headers;
  }

  /// Builds 4-header link bridge headers required by POST /devices/link.
  static Map<String, String> buildLinkBridgeHeaders({
    required String deviceName,
    required String deviceToken,
    String? username,
    String? userToken,
    String? accessToken,
  }) {
    final token = accessToken ?? AuthService.instance.accessToken;
    final user = username ?? AuthService.instance.currentUsername;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Device-Name': deviceName,
      'X-Device-Token': deviceToken,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (user != null && user.isNotEmpty) {
      headers['X-User-Name'] = user;
    }
    if (userToken != null && userToken.isNotEmpty) {
      headers['X-User-Token'] = userToken;
    }
    return headers;
  }

  /// Builds scoped headers required by /scan/* and POST /chat/query.
  static Map<String, String> buildScanHeaders({
    required String requestType,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
    String? accessToken,
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
      final token = accessToken ?? AuthService.instance.accessToken;
      final user = username ?? AuthService.instance.currentUsername;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'X-Request-Type': 'user',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      if (user != null && user.isNotEmpty) {
        headers['X-User-Name'] = user;
      }
      if (userToken != null && userToken.isNotEmpty) {
        headers['X-User-Token'] = userToken;
      }
      return headers;
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

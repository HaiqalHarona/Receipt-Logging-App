/// API configuration for Receipt Logger backend (FastAPI @ port 8085).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../device_identity_service.dart';

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
  static const Duration timeout = Duration(seconds: 30);

  /// Builds the standard identity headers required by all protected endpoints.
  ///
  /// [deviceId]    — unique hardware fingerprint (persistent).
  /// [deviceToken] — secret token stored securely after device registration.
  /// [userId]      — optional; only sent when the user is signed in.
  static Map<String, String> buildHeaders({
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) {
    return {
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-Device-Token': deviceToken,
      if (userId != null && userId.isNotEmpty) 'X-User-ID': userId,
    };
  }
}

/// API configuration for Receipt Logger backend (FastAPI @ port 8085).
///
/// To target a physical device on the same network, replace [baseUrl]
/// with your machine's local IP, e.g. "http://192.168.1.x:8085/api/v1".
/// Android emulators should use "http://10.0.2.2:8085/api/v1".
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  ApiConfig._();

  /// Base URL for backend read dynamically from .env
  static String get baseUrl => dotenv.get('API_BASE_URL', fallback: 'http://100.98.101.54:8085/api/v1');

  /// Supabase Project URL read dynamically from .env
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');

  /// Supabase Key read dynamically from .env
  static String get supabaseKey => dotenv.get('SUPABASE_KEY', fallback: '');

  /// Gemini API Key read dynamically from .env
  static String get geminiApiKey => dotenv.get('GEMINI_API_KEY', fallback: '');

  /// Default request timeout — Gemini vision can take ~3s.
  static const Duration timeout = Duration(seconds: 30);

  /// Builds the standard identity headers required by all protected endpoints.
  ///
  /// [deviceId]    — unique hardware fingerprint (generated once on first boot).
  /// [deviceToken] — secret token stored in secure storage after device registration.
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

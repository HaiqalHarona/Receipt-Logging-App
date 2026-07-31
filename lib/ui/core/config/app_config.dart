import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Application Configuration & API Endpoints
class AppConfig {
  AppConfig._();

  // ── DEPLOYED DOMAIN NAME OR IP ADDRESS ─────────────────────────────────────
  /// Dynamic base URL read from .env file
  static String get baseUrl => dotenv.get('API_BASE_URL', fallback: 'http://100.98.101.54:8085/api/v1');

  // ── SUPABASE CONFIGURATION (IF APPLICABLE) ─────────────────────────────────
  /// Deployed Supabase URL read from .env
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');

  /// Supabase Anon Key read from .env
  static String get supabaseAnonKey => dotenv.get('SUPABASE_KEY', fallback: '');

  // ── API ENDPOINT PATHS ─────────────────────────────────────────────────────
  static String get receiptsEndpoint => '$baseUrl/v1/receipts';
  static String get ocrProcessEndpoint => '$baseUrl/v1/ocr/process';
  static String get aiAssistantEndpoint => '$baseUrl/v1/ai/chat';
  static String get authEndpoint => '$baseUrl/v1/auth';
  static String get analyticsEndpoint => '$baseUrl/v1/analytics';

  // ── TIMEOUTS & NETWORK SETTINGS ───────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

class AppConstants {
  // App info
  static const String appName = 'Receipt Logger';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrl = 'https://your-backend.fly.dev'; // Override in env
  static const Duration apiTimeout = Duration(seconds: 30);

  // Local storage
  static const String isarDbName = 'receipt_db';

  // Receipt categories
  static const List<String> categories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Entertainment',
    'Healthcare',
    'Utilities',
    'Other',
  ];

  // App config keys
  static const String keyAppConfig = 'app_config';
  static const String keyThemeMode = 'theme_mode';
  static const String keyApiUrl = 'api_url';
}

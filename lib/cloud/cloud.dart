/// Primary barrel export for the `cloud` module.
///
/// Import this file to access all cloud-related DTOs, the HTTP client,
/// API configuration, and device identity service:
///
/// ```dart
/// import 'package:reciept_logging/cloud/cloud.dart';
/// ```
library;

// API layer
export 'api/api_config.dart';
export 'api/backend_api_client.dart';

// Models
export 'models/device_models.dart';
export 'models/user_models.dart';
export 'models/receipt_models.dart';
export 'models/chat_models.dart';

// Services
export 'services/device_identity_service.dart';

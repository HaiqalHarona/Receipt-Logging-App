import 'dart:ui';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/theme/theme_controller.dart';
import 'services/isar_service.dart';
import 'data/models/receipt_isar.dart';
import 'data/models/conversation_isar.dart';
import 'data/models/chat_message_isar.dart';
import 'data/repositories/receipt_repository.dart';
import 'data/repositories/conversation_repository.dart';

import 'services/device_identity_service.dart';
import 'services/api/backend_api_client.dart';
import 'cloud/services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/currency_service.dart';
import 'services/app_logger_service.dart';
import 'services/crypto_service.dart';
import 'services/sync_coordinator.dart';
import 'cloud/api/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();

  // Load .env if present in development assets or ignore gracefully when using --dart-define
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    AppLogger.debug('Config', 'No .env asset loaded; using environment definitions or defaults.');
  }

  // Initialize crypto service and secure storage keys
  await CryptoService.instance.init();

  // Initialize database, repositories, and persistent device identity
  await IsarService.init(schemas: [
    ReceiptIsarModelSchema,
    ConversationIsarModelSchema,
    ChatMessageIsarModelSchema,
  ]);
  await DeviceIdentityService.instance.init(BackendApiClient.instance);
  await AuthService.instance.init();
  await ReceiptRepository.instance.init();
  await ConversationRepository.instance.init();
  await CloudSyncService.instance.syncOnLogin();
  await SyncCoordinator.instance.init();
  await CurrencyService.instance.init();
  await AppThemeController.instance.loadPersistedTheme();

  // Catch unhandled Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError', details.exceptionAsString(), details.exception, details.stack);
  };

  // Catch unhandled platform/isolate asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('PlatformError', error.toString(), error, stack);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    if (isDebug) {
      return ErrorWidget(details.exception);
    }
    return Container(
      alignment: Alignment.center,
      color: AppTheme.darkBackground,
      child: const Text(
        'An error occurred',
        style: TextStyle(color: Colors.white70, fontSize: 12),
        textDirection: TextDirection.ltr,
      ),
    );
  };

  runApp(const ReceiptLoggerApp());
}

class ReceiptLoggerApp extends StatelessWidget {
  const ReceiptLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: ApiConfig.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: appRouter,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: AppThemeController.instance,
          builder: (context, _) {
            final controller = AppThemeController.instance;

            final customDarkTheme = NeumorphicThemeData(
              baseColor: controller.currentBaseColor,
              accentColor: controller.accentColor,
              variantColor: controller.currentBaseColor,
              lightSource: LightSource.topLeft,
              depth: controller.neuDepth,
              intensity: 0.88,
              shadowDarkColor: controller.shadowDarkColor,
              shadowLightColor: controller.shadowLightColor,
              shadowDarkColorEmboss: controller.shadowDarkColorEmboss,
              shadowLightColorEmboss: controller.shadowLightColorEmboss,
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: controller.textColor),
                bodyMedium: TextStyle(color: controller.secondaryTextColor),
              ),
            );

            final customLightTheme = NeumorphicThemeData(
              baseColor: controller.currentBaseColor,
              accentColor: controller.accentColor,
              variantColor: controller.currentBaseColor,
              lightSource: LightSource.topLeft,
              depth: controller.neuDepth,
              intensity: 0.80,
              shadowDarkColor: controller.shadowDarkColor,
              shadowLightColor: controller.shadowLightColor,
              shadowDarkColorEmboss: controller.shadowDarkColorEmboss,
              shadowLightColorEmboss: controller.shadowLightColorEmboss,
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: controller.textColor),
                bodyMedium: TextStyle(color: controller.secondaryTextColor),
              ),
            );

            return NeumorphicTheme(
              themeMode: controller.themeMode,
              darkTheme: customDarkTheme,
              theme: customLightTheme,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(controller.fontScale),
                ),
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}

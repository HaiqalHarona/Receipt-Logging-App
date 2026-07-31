import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/theme/theme_controller.dart';
import 'services/isar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await IsarService.init(schemas: []);

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
      title: 'Receipt Logger',
      debugShowCheckedModeBanner: false,
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
              depth: 5,
              intensity: 0.88,
              shadowDarkColor: controller.shadowDarkColor,
              shadowLightColor: controller.shadowLightColor,
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
              depth: 6,
              intensity: 0.80,
              shadowDarkColor: controller.shadowDarkColor,
              shadowLightColor: controller.shadowLightColor,
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: controller.textColor),
                bodyMedium: TextStyle(color: controller.secondaryTextColor),
              ),
            );

            return NeumorphicTheme(
              themeMode: controller.themeMode,
              darkTheme: customDarkTheme,
              theme: customLightTheme,
              child: child!,
            );
          },
        );
      },
    );
  }
}
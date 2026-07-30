import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/theme/theme_controller.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
            final currentPreset = controller.currentPreset;

            final customDarkTheme = NeumorphicThemeData(
              baseColor: currentPreset.baseColor,
              accentColor: controller.accentColor,
              variantColor: currentPreset.baseColor,
              lightSource: LightSource.topLeft,
              depth: 6,
              intensity: 0.9,
              shadowDarkColor: const Color(0xFF0D0D14),
              shadowLightColor: const Color(0xFF4A4A60),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: controller.textColor),
                bodyMedium: TextStyle(color: currentPreset.secondaryTextColor),
              ),
            );

            final customLightTheme = NeumorphicThemeData(
              baseColor: AppTheme.lightBackground,
              accentColor: controller.accentColor,
              variantColor: AppTheme.lightCardBackground,
              lightSource: LightSource.topLeft,
              depth: 5,
              intensity: 0.7,
              shadowDarkColor: const Color(0xFFA3B1C6),
              shadowLightColor: const Color(0xFFFFFFFF),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: controller.textColor),
                bodyMedium: const TextStyle(color: AppTheme.lightTextSecondary),
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
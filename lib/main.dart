import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/core/providers/theme_provider.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ReceiptLoggerApp(),
    ),
  );
}

class ReceiptLoggerApp extends ConsumerWidget {
  const ReceiptLoggerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appThemeMode = ref.watch(themeProvider);
    final isDark = appThemeMode == AppThemeMode.dark;
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;

    return NeumorphicTheme(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      child: MaterialApp.router(
        title: 'Receipt Logger',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          fontFamily: 'Inter',
          scaffoldBackgroundColor: AppTheme.lightBackground,
          colorScheme: const ColorScheme.light(
            primary: AppTheme.accentColor,
            secondary: AppTheme.accentLight,
            surface: AppTheme.lightBackground,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          fontFamily: 'Inter',
          scaffoldBackgroundColor: AppTheme.darkBackground,
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentColor,
            secondary: AppTheme.accentLight,
            surface: AppTheme.darkBackground,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppTheme.darkTextPrimary,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
          ),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}
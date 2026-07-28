import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

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

    return NeumorphicTheme(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      child: MaterialApp.router(
        title: 'Receipt Logger',
        debugShowCheckedModeBanner: false,
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
        routerConfig: router,
      ),
    );
  }
}
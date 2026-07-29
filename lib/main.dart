import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'ui/core/router/app_router.dart';
import 'ui/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReceiptLoggerApp());
}

class ReceiptLoggerApp extends StatelessWidget {
  const ReceiptLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicTheme(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      theme: AppTheme.lightNeumorphicTheme,
      child: MaterialApp.router(
        title: 'Receipt Logger',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppTheme.darkBackground,
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
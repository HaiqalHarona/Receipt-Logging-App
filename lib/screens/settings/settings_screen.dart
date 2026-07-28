import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/core/theme/app_theme.dart';
import 'package:reciept_logging/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: AppTheme.lightBackground,
        appBar: NeumorphicAppBar(
          title: const Text('Settings'),
          leading: NeumorphicButton(
            style: const NeumorphicStyle(
              boxShape: NeumorphicBoxShape.circle(),
            ),
            padding: const EdgeInsets.all(8),
            onPressed: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Neumorphic(
              style: AppTheme.cardStyle,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dark Mode', style: AppTheme.titleLarge),
                        Text('Switch to dark theme', style: AppTheme.bodyMedium),
                      ],
                    ),
                    NeumorphicSwitch(
                      value: isDark,
                      onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Neumorphic(
              style: AppTheme.cardStyle,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About', style: AppTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Version 1.0.0', style: AppTheme.bodyMedium),
                    Text('Receipt Logger — Scan & Track Expenses', style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

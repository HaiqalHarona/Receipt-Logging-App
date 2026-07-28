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

    final primaryColor = AppTheme.textPrimaryOf(context);
    final secondaryColor = AppTheme.textSecondaryOf(context);

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColorOf(context),
        appBar: NeumorphicAppBar(
          title: Text('Settings', style: TextStyle(color: primaryColor)),
          leading: NeumorphicButton(
            style: const NeumorphicStyle(
              boxShape: NeumorphicBoxShape.circle(),
            ),
            padding: const EdgeInsets.all(8),
            onPressed: () => context.pop(),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: primaryColor),
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
                        Text('Dark Mode', style: AppTheme.titleLarge.copyWith(color: primaryColor)),
                        Text('Switch to dark theme', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
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
                    Text('About', style: AppTheme.titleLarge.copyWith(color: primaryColor)),
                    const SizedBox(height: 8),
                    Text('Version 1.0.0', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                    Text('Receipt Logger — Scan & Track Expenses', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
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

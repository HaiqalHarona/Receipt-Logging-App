import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final isDark = controller.themeMode == ThemeMode.dark;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            bottomNavigationBar: const AppBottomNavBar(currentPath: '/settings'),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Settings",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // User Profile Card
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const NeumorphicIconBadge(
                                  icon: Icons.person,
                                  iconSize: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Nino",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Basic Plan",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.star_rounded, color: accent),
                                  onPressed: () {
                                    context.push('/paywall');
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Appearance & Theme Customization Navigation Tile
                          NeumorphicCardWidget(
                            onTap: () => context.push('/customization'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                const NeumorphicIconBadge(
                                  icon: Icons.palette_rounded,
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Appearance & Theme",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${controller.currentPreset.name} • ${isDark ? 'Dark' : 'Light'} Mode",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSecondary,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Currency Setting Card
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Currency",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  "USD (\$)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Export Database Setting Card
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Export Database (JSON/CSV)",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  "Export",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
        final accent = controller.accentColor;

        // Accent Color Palette Options
        final accentOptions = [
          const Color(0xFF00FF85), // Neon Emerald
          const Color(0xFFFF2A6D), // Neon Rose
          const Color(0xFF38BDF8), // Electric Cyan
          const Color(0xFFA855F7), // Vivid Purple
          const Color(0xFFF59E0B), // Vibrant Amber
          const Color(0xFFEF4444), // Crimson Red
        ];

        // Text Color Palette Options
        final textOptions = [
          const Color(0xFFFFFFFF), // Pure White
          const Color(0xFFE0E0E0), // Soft Gray
          const Color(0xFFE0F2FE), // Ice Tint
          const Color(0xFFECFDF5), // Mint Tint
          const Color(0xFFFAF5FF), // Violet Tint
          const Color(0xFF1E293B), // Slate Dark (Light mode)
        ];

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                    "👑 Pro Member",
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

                      // Section Title: Theme Customization
                      Text(
                        "Theme & Appearance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Light / Dark Mode Toggle Card
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isDark ? "Dark Mode Theme" : "Light Mode Theme",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            NeumorphicSwitch(
                              value: isDark,
                              style: NeumorphicSwitchStyle(
                                activeTrackColor: accent,
                                inactiveTrackColor: isDark ? const Color(0xFF12121F) : const Color(0xFFCBD5E1),
                              ),
                              onChanged: (val) {
                                controller.toggleThemeMode(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Color Palette Presets
                      Text(
                        "Color Palette Presets",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: AppThemeController.presets.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final preset = AppThemeController.presets[index];
                            final isSelected = controller.selectedPresetIndex == index && !controller.useCustomColors;
                            return NeumorphicCardWidget(
                              onTap: () => controller.selectPreset(index),
                              color: preset.baseColor,
                              depth: isSelected ? -3 : 4,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: preset.accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: preset.textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Custom Accent / Button Color Picker
                      Text(
                        "Button & Accent Color",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: accentOptions.map((color) {
                          final isSelected = controller.accentColor.value == color.value;
                          return GestureDetector(
                            onTap: () => controller.updateCustomAccentColor(color),
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                shape: NeumorphicShape.convex,
                                boxShape: const NeumorphicBoxShape.circle(),
                                depth: isSelected ? -4 : 4,
                                color: color,
                              ),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Custom Text Color Picker
                      Text(
                        "Text Color",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: textOptions.map((color) {
                          final isSelected = controller.textColor.value == color.value;
                          return GestureDetector(
                            onTap: () => controller.updateCustomTextColor(color),
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                shape: NeumorphicShape.convex,
                                boxShape: const NeumorphicBoxShape.circle(),
                                depth: isSelected ? -4 : 4,
                                color: color,
                              ),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: color == const Color(0xFFFFFFFF) ? Colors.black : Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Currency & Export Settings Card
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
              const AppBottomNavBar(currentPath: '/settings'),
            ],
          ),
        ),
      ),
    );
  },
);
  }
}







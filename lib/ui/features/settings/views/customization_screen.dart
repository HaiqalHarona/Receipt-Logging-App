import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

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

        final accentOptions = [
          const Color(0xFF00FF85),
          const Color(0xFFFF2A6D),
          const Color(0xFF38BDF8),
          const Color(0xFFA855F7),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
        ];

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with Back Button
                          Row(
                            children: [
                              NeumorphicIconBadge(
                                icon: Icons.arrow_back_rounded,
                                iconSize: 20,
                                onTap: () => context.pop(),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                "Theme Customization",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Light / Dark Mode Toggle Card
                          NeumorphicCardWidget(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Theme Mode",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isDark ? "Dark Theme Active" : "Light Theme Active",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
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
                          const SizedBox(height: 24),

                          // Color Palette Presets Section
                          Text(
                            isDark ? "Dark Mode Palette Presets" : "Light Mode Palette Presets",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 85,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: AppThemeController.currentPresets.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final presetsList = AppThemeController.currentPresets;
                                final preset = presetsList[index];
                                final isSelected = controller.selectedPresetIndex == index;
                                final previewBase = isDark ? preset.darkBaseColor : preset.lightBaseColor;
                                final previewAccent = isDark ? preset.darkAccentColor : preset.lightAccentColor;
                                final previewText = isDark ? preset.darkTextColor : preset.lightTextColor;

                                return NeumorphicCardWidget(
                                  onTap: () => controller.selectPreset(index),
                                  color: previewBase,
                                  depth: isSelected ? -3 : 4,
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: previewAccent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            preset.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: previewText,
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
                          const SizedBox(height: 28),

                          // Accent / Button Color Picker
                          Text(
                            "Button & Accent Color",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: accentOptions.map((color) {
                              final isSelected = controller.accentColor == color;
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
                                    width: 40,
                                    height: 40,
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
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

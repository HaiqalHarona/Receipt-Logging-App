// File: lib/ui/features/settings/views/policies_tour_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../../services/app_logger_service.dart';

/// Dedicated sub-screen presenting Legal & Compliance policies alongside
/// the interactive onboarding App Walkthrough.
class PoliciesTourScreen extends StatelessWidget {
  const PoliciesTourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;
        final fontScale = controller.fontScale;

        return AppGradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Top Navigation Bar (aligned to 20px margin matching UserSettingsScreen)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NeumorphicCircularButton(
                          icon: Icons.arrow_back_rounded,
                          iconSize: 20,
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/settings');
                            }
                          },
                        ),
                        Text(
                          "Policies & Tour",
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18 * fontScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 40), // Balance back button
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // ── 1. LEGAL DOCUMENTS SECTION ─────────────────────────
                  _buildSectionHeader("LEGAL DOCUMENTS", textSecondary),
                  const SizedBox(height: 8),
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: controller.neuDepth,
                      intensity: 0.8,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(16)),
                      color: baseColor,
                    ),
                    child: Column(
                      children: [
                        _buildNavRow(
                          context: context,
                          icon: Icons.security_rounded,
                          title: "Privacy Policy",
                          subtitle: "GDPR, CCPA/CPRA & Zero AI Training",
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isTop: true,
                          onTap: () {
                            AppLogger.info('UI', 'User tapped Privacy Policy');
                            context.push('/legal/privacy');
                          },
                        ),
                        _buildDivider(textSecondary),
                        _buildNavRow(
                          context: context,
                          icon: Icons.gavel_rounded,
                          title: "Terms of Service",
                          subtitle: "Acceptable use & governing law",
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () {
                            AppLogger.info('UI', 'User tapped Terms of Service');
                            context.push('/legal/terms');
                          },
                        ),
                        _buildDivider(textSecondary),
                        _buildNavRow(
                          context: context,
                          icon: Icons.cookie_outlined,
                          title: "Cookie & Storage Policy",
                          subtitle: "Secure tokens, cache & local database",
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () {
                            AppLogger.info('UI', 'User tapped Cookie Policy');
                            context.push('/legal/cookies');
                          },
                        ),
                        _buildDivider(textSecondary),
                        _buildNavRow(
                          context: context,
                          icon: Icons.accessibility_new_rounded,
                          title: "Accessibility Statement",
                          subtitle: "ADA Title III & WCAG 2.1 AA",
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isBottom: true,
                          onTap: () {
                            AppLogger.info(
                                'UI', 'User tapped Accessibility Statement');
                            context.push('/legal/accessibility');
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 2. APP TOUR SECTION ─────────────────────────────────
                  _buildSectionHeader("APP TOUR", textSecondary),
                  const SizedBox(height: 8),
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: controller.neuDepth,
                      intensity: 0.8,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(16)),
                      color: baseColor,
                    ),
                    child: _buildNavRow(
                      context: context,
                      icon: Icons.explore_outlined,
                      title: "App Walkthrough",
                      subtitle: "Revisit the welcome features & privacy tour",
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isTop: true,
                      isBottom: true,
                      onTap: () {
                        AppLogger.info('UI', 'User launched App Walkthrough');
                        context.push('/onboarding');
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: textSecondary,
        ),
      ),
    );
  }

  Widget _buildDivider(Color textSecondary) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: textSecondary.withValues(alpha: 0.15),
      indent: 52,
    );
  }

  Widget _buildNavRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
    bool isTop = false,
    bool isBottom = false,
  }) {
    return NeumorphicPressableRow(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isTop ? const Radius.circular(16) : Radius.zero,
        bottom: isBottom ? const Radius.circular(16) : Radius.zero,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: textSecondary, size: 14),
        ],
      ),
    );
  }
}

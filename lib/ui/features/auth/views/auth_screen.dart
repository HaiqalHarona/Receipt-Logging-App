// File: lib/ui/features/auth/views/auth_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../cloud/api/api_config.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final canPop = GoRouter.maybeOf(context)?.canPop() ?? false;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Top Navigation / Close Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canPop)
                          GestureDetector(
                            onTap: () {
                              AppLogger.info(
                                  'UI', 'User tapped Back on AuthScreen');
                              context.pop();
                            },
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                depth: 4,
                                intensity: 0.85,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(12)),
                                color: controller.currentBaseColor,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back_rounded,
                                        color: textPrimary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Back",
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 40),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App Logo Badge
                            Neumorphic(
                              style: NeumorphicStyle(
                                depth: 6,
                                intensity: 0.9,
                                boxShape: const NeumorphicBoxShape.circle(),
                                color: controller.currentBaseColor,
                                border: NeumorphicBorder(
                                  color: accent.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      accent.withValues(alpha: 0.20),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: accent,
                                  size: 44,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // App Title & Tagline
                            Text(
                              ApiConfig.appName,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Smart receipt scanning & automated expense management",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Feature Badges Card
                            NeumorphicCardWidget(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 16),
                              child: Column(
                                children: [
                                  _buildFeatureRow(
                                    icon: Icons.flash_on_rounded,
                                    title: "AI Vision Parsing",
                                    subtitle:
                                        "Clean & structured line-item extraction",
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeatureRow(
                                    icon: Icons.auto_graph_rounded,
                                    title: "Smart Spending Insights",
                                    subtitle:
                                        "Interactive analytics & expense breakdown",
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeatureRow(
                                    icon: Icons.cloud_sync_rounded,
                                    title: "Multi-Device Sync",
                                    subtitle:
                                        "Seamless cloud backup when signed in",
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),

                            // ── Primary Action: Sign In ───────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: NeumorphicButtonWidget(
                                onPressed: () {
                                  AppLogger.info('UI',
                                      'User tapped Sign In on AuthScreen');
                                  context.push('/login');
                                },
                                child: const Center(
                                  child: Text(
                                    "Sign In",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Secondary Action: Create Account ──────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: GestureDetector(
                                onTap: () {
                                  AppLogger.info('UI',
                                      'User tapped Create Account on AuthScreen');
                                  context.push('/signup');
                                },
                                child: Neumorphic(
                                  style: NeumorphicStyle(
                                    depth: 4,
                                    intensity: 0.85,
                                    boxShape: NeumorphicBoxShape.roundRect(
                                        BorderRadius.circular(14)),
                                    color: controller.currentBaseColor,
                                    border: NeumorphicBorder(
                                      color: accent.withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Create Account",
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Continue as Guest ─────────────────────────────
                            GestureDetector(
                              onTap: () {
                                AppLogger.info('UI',
                                    'User tapped Continue as Guest on AuthScreen');
                                if (canPop) {
                                  context.pop();
                                } else {
                                  context.go('/dashboard');
                                }
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Continue as Guest",
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: accent, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
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
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../core/widgets/alpha_breadcrumb_badge.dart';
import '../../../../cloud/api/api_config.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/device_identity_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../../services/currency_service.dart';
import '../../../../services/local_image_cache_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _onLogout(BuildContext context) async {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 0,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
              color: NeumorphicTheme.baseColor(ctx),
              border: NeumorphicBorder(
                color: Colors.red.shade700.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.red.shade600, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Are you sure you want to log out? Your cloud session will be cleared and the app will return to guest mode.",
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await AuthService.instance.clearSession();
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: "Logged out successfully.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        CurrencyService.instance,
        AuthService.instance,
        LocalImageCacheService.instance,
      ]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final currentCurrency = CurrencyService.instance.currentCurrency;
        final currentSymbol = CurrencyService.instance.currentSymbol;
        final isLoggedIn = AuthService.instance.isLoggedIn;
        final username = AuthService.instance.currentUsername ?? "User";
        final email = AuthService.instance.currentEmail ?? "";

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 16, bottom: 120),
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
                    const SizedBox(height: 4),
                    Text(
                      "Configure your preferences",
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── SECTION 0: ACCOUNT / GUEST BANNER ───────────────────
                    if (!isLoggedIn) ...[
                      // Guest Onboarding Banner
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                NeumorphicIconBadge(
                                  icon: Icons.cloud_sync_rounded,
                                  iconSize: 22,
                                  iconColor: accent,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Sign In or Register",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Sync receipts across devices with cloud backup",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: NeumorphicButtonWidget(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                onPressed: () => context.push('/auth'),
                                child: const Center(
                                  child: Text(
                                    "Get Started",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Logged-in Account Section
                      _buildSectionHeader("ACCOUNT", textSecondary),
                      const SizedBox(height: 8),
                      _buildSectionContainer(
                        children: [
                          // Profile Summary Row
                          InkWell(
                            onTap: () => context.push('/user-settings'),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  // Avatar Initial Badge
                                  Neumorphic(
                                    style: NeumorphicStyle(
                                      depth: 3,
                                      boxShape:
                                          const NeumorphicBoxShape.circle(),
                                      color: accent.withValues(alpha: 0.15),
                                      border: NeumorphicBorder(
                                        color: accent.withValues(alpha: 0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child:
                                          _buildAvatarBadge(username, accent),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
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
                          ),
                          _buildDivider(textSecondary),
                          // Log Out Action Row
                          InkWell(
                            onTap: () => _onLogout(context),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Colors.redAccent.shade200,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Log Out",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── SECTION 1: APPEARANCE ─────────────────────────────
                    _buildSectionHeader("APPEARANCE", textSecondary),
                    const SizedBox(height: 8),
                    _buildSectionContainer(
                      children: [
                        // Customization & Theme Row
                        InkWell(
                          onTap: () => context.push('/customization'),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Customization & Theme",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Adjust app colors, presets & accents",
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
                        ),
                        _buildDivider(textSecondary),
                        // Appearance Mode Row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Theme Mode',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildModeChip(
                                icon: Icons.dark_mode_rounded,
                                label: 'Dark',
                                mode: ThemeMode.dark,
                                controller: controller,
                                accent: accent,
                                textPrimary: textPrimary,
                              ),
                              const SizedBox(width: 8),
                              _buildModeChip(
                                icon: Icons.light_mode_rounded,
                                label: 'Light',
                                mode: ThemeMode.light,
                                controller: controller,
                                accent: accent,
                                textPrimary: textPrimary,
                              ),
                              const SizedBox(width: 8),
                              _buildModeChip(
                                icon: Icons.phone_android_rounded,
                                label: 'Auto',
                                mode: ThemeMode.system,
                                controller: controller,
                                accent: accent,
                                textPrimary: textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── SECTION 2: DATA & PREFERENCES ─────────────────────
                    _buildSectionHeader("DATA & PREFERENCES", textSecondary),
                    const SizedBox(height: 8),
                    _buildSectionContainer(
                      children: [
                        // Currency Selector Row
                        InkWell(
                          onTap: () => _showCurrencyPicker(
                              context, textPrimary, textSecondary, accent),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Default Display Currency",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "All receipts convert automatically",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "$currentCurrency ($currentSymbol)",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildDivider(textSecondary),
                        // Export Database Row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
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
                    const SizedBox(height: 24),

                    // ── SECTION 3: SUPPORT & FEEDBACK ────────────────────
                    _buildSectionHeader("SUPPORT & FEEDBACK", textSecondary),
                    const SizedBox(height: 8),
                    _buildSectionContainer(
                      children: [
                        // Submit Feedback Row
                        InkWell(
                          onTap: () => _showFeedbackBottomSheet(
                            context,
                            accent,
                            textPrimary,
                            textSecondary,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Submit Feedback",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Report an issue directly to our team",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.feedback_outlined,
                                  color: accent,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── SECTION 4: LEGAL & COMPLIANCE ─────────────────────
                    _buildSectionHeader("LEGAL & COMPLIANCE", textSecondary),
                    const SizedBox(height: 8),
                    _buildSectionContainer(
                      children: [
                        // Privacy Policy Row
                        InkWell(
                          onTap: () => context.push('/legal/privacy'),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Privacy Policy",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "GDPR, CCPA/CPRA, Zero AI Training & Encryption",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildDivider(textSecondary),

                        // Terms of Service Row
                        InkWell(
                          onTap: () => context.push('/legal/terms'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Terms of Service",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Acceptable use, AI disclaimers & governing law",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildDivider(textSecondary),

                        // Cookie & Storage Policy Row
                        InkWell(
                          onTap: () => context.push('/legal/cookies'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Cookie & Storage Policy",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Local database, secure tokens & cache details",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildDivider(textSecondary),

                        // Accessibility Statement Row
                        InkWell(
                          onTap: () => context.push('/legal/accessibility'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Accessibility Statement",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "ADA Title III, WCAG 2.1 AA & contrast support",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildDivider(textSecondary),

                        // Onboarding Walkthrough Row
                        InkWell(
                          onTap: () {
                            AppLogger.info('UI',
                                'User tapped App Walkthrough from SettingsScreen');
                            context.push('/onboarding');
                          },
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "App Walkthrough",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Revisit the welcome features & privacy tour",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: textSecondary,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (kDebugMode && ApiConfig.isDevelopment) ...[
                      const SizedBox(height: 24),
                      // ── SECTION 5: DEVELOPER TOOLS ────────────────────────
                      _buildSectionHeader("DEVELOPER TOOLS", textSecondary),
                      const SizedBox(height: 8),
                      _buildSectionContainer(
                        children: [
                          // Isar Database Viewer Row
                          InkWell(
                            onTap: () => context.push('/settings/db-viewer'),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Isar Database Viewer",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Inspect stored receipts & live storage",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.storage_rounded,
                                    color: accent,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (ApiConfig.isStaging && !ApiConfig.isProduction)
                      const Center(
                        child: AlphaBreadcrumbBadge(),
                      )
                    else
                      Center(
                        child: Text(
                          '${ApiConfig.appName} v${ApiConfig.appVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary.withValues(alpha: 0.6),
                          ),
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

  Widget _buildSectionHeader(String label, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textSecondary.withValues(alpha: 0.8),
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return NeumorphicCardWidget(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDivider(Color textSecondary) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: textSecondary.withValues(alpha: 0.15),
    );
  }

  Widget _buildModeChip({
    required IconData icon,
    required String label,
    required ThemeMode mode,
    required AppThemeController controller,
    required Color accent,
    required Color textPrimary,
  }) {
    final isSelected = controller.themeMode == mode;
    return GestureDetector(
      onTap: () => controller.setThemeMode(mode),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: isSelected ? -3 : 4,
          intensity: 0.85,
          color: isSelected ? accent.withValues(alpha: 0.12) : null,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(10)),
          border: isSelected
              ? NeumorphicBorder(
                  color: accent.withValues(alpha: 0.4), width: 1.0)
              : const NeumorphicBorder.none(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? accent : textPrimary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color:
                        isSelected ? accent : textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeumorphicTheme.baseColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Display Currency",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Spending totals and receipt prices will convert automatically.",
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: CurrencyService.supportedCurrencies.entries
                        .map((entry) {
                      final code = entry.key;
                      final info = entry.value;
                      final isSelected =
                          code == CurrencyService.instance.currentCurrency;

                      return ListTile(
                        onTap: () {
                          CurrencyService.instance.setCurrency(code);
                          Navigator.of(context).pop();
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? accent
                              : textSecondary.withValues(alpha: 0.1),
                          child: Text(
                            info.symbol,
                            style: TextStyle(
                              color: isSelected ? Colors.white : textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          "${info.code} — ${info.name}",
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: accent)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarBadge(String username, Color accent) {
    if (AuthService.instance.isLoggedIn) {
      final profile = AuthService.instance.cachedProfile;
      final avatarPath = profile?.avatarImagePath;
      if (avatarPath != null &&
          avatarPath.isNotEmpty &&
          File(avatarPath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(avatarPath),
            fit: BoxFit.cover,
            width: 40,
            height: 40,
            errorBuilder: (_, __, ___) => _buildAvatarInitial(username, accent),
          ),
        );
      }

      return FutureBuilder<File?>(
        future: LocalImageCacheService.instance.getOrFetchAvatar(size: 'small'),
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.existsSync()) {
            return ClipOval(
              child: Image.file(
                snapshot.data!,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) =>
                    _buildAvatarInitial(username, accent),
              ),
            );
          }
          return _buildAvatarInitial(username, accent);
        },
      );
    }

    return _buildAvatarInitial(username, accent);
  }

  Widget _buildAvatarInitial(String username, Color accent) {
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : "U",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );
  }

  DateTime? _lastFeedbackSubmitTime;

  void _showFeedbackBottomSheet(
    BuildContext context,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    AppLogger.info('UI', 'User opened Submit Feedback bottom sheet');
    final defaultSender = AuthService.instance.currentUsername ??
        DeviceIdentityService.instance.deviceId;
    final senderController = TextEditingController(text: defaultSender);
    final descriptionController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setModalState) {
            final descLength = descriptionController.text.trim().length;
            final isValidLength = descLength >= 25;
            final baseColor = NeumorphicTheme.baseColor(ctx);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.feedback_outlined,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Submit Feedback",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Help us improve your receipt experience",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded,
                                color: textSecondary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sender Input
                      Text(
                        "Sender",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -3,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                          color: baseColor,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: TextField(
                          controller: senderController,
                          maxLength: 100,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              null,
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter your username or ID",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: accent,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Feedback Description",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            isValidLength
                                ? "$descLength / 2000 chars"
                                : "$descLength / 25 min chars",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isValidLength
                                  ? (descLength <= 2000
                                      ? const Color(0xFF10B981)
                                      : Colors.red.shade400)
                                  : Colors.orange.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -3,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                          color: baseColor,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: TextField(
                          controller: descriptionController,
                          maxLength: 2000,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              null, // custom counter in header row above
                          maxLines: 5,
                          minLines: 3,
                          onChanged: (_) => setModalState(() {}),
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                "Tell us what you like or what we can improve (25 to 2000 characters)...",
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: NeumorphicButtonWidget(
                          borderRadius: 14,
                          onPressed: (!isValidLength ||
                                  descLength > 2000 ||
                                  isSubmitting)
                              ? null
                              : () async {
                                  final sender = senderController.text.trim();
                                  final desc =
                                      descriptionController.text.trim();

                                  if (sender.isEmpty) {
                                    AppSnackBar.show(
                                      context,
                                      message: "Sender cannot be empty.",
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (sender.length > 100) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Sender cannot exceed 100 characters.",
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (desc.length < 25) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Feedback must be at least 25 characters long.",
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (desc.length > 2000) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          "Feedback cannot exceed 2000 characters.",
                                      isError: true,
                                    );
                                    return;
                                  }

                                  // Client-side 30s rate limit guard
                                  if (_lastFeedbackSubmitTime != null) {
                                    final elapsed = DateTime.now()
                                        .difference(_lastFeedbackSubmitTime!)
                                        .inSeconds;
                                    if (elapsed < 30) {
                                      final remaining = 30 - elapsed;
                                      AppSnackBar.show(
                                        context,
                                        message:
                                            "Please wait $remaining seconds before submitting feedback again.",
                                        isError: true,
                                      );
                                      return;
                                    }
                                  }

                                  setModalState(() => isSubmitting = true);
                                  AppLogger.info('UI',
                                      'Submitting feedback: sender=$sender, len=${desc.length}');

                                  try {
                                    final result = await BackendApiClient
                                        .instance
                                        .submitFeedback(
                                      sender: sender,
                                      description: desc,
                                    );

                                    _lastFeedbackSubmitTime = DateTime.now();

                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (context.mounted) {
                                      AppSnackBar.show(
                                        context,
                                        message: result['message'] ??
                                            "Thank you! Your feedback has been received.",
                                      );
                                    }
                                  } catch (e) {
                                    AppLogger.error(
                                        'UI', 'Failed to submit feedback', e);
                                    if (context.mounted) {
                                      AppSnackBar.show(
                                        context,
                                        message:
                                            "Failed to submit feedback: $e",
                                        isError: true,
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          child: Center(
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Submit Feedback",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
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
      },
    );
  }
}

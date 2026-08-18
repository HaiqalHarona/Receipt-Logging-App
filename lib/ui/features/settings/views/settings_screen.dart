// File: lib/ui/features/settings/views/settings_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../services/currency_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge(
          [AppThemeController.instance, CurrencyService.instance]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final currentCurrency = CurrencyService.instance.currentCurrency;
        final currentSymbol = CurrencyService.instance.currentSymbol;

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
                    const SizedBox(height: 24),

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
                              Text(
                                'Theme Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const Spacer(),
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

                    // ── SECTION 3: DEVELOPER TOOLS ────────────────────────
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected ? accent : textPrimary.withValues(alpha: 0.6),
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
}

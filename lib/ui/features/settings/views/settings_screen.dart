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

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([AppThemeController.instance, CurrencyService.instance]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final isDark = controller.themeMode == ThemeMode.dark;
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
                    const SizedBox(height: 4),
                    Text(
                      "Configure your preferences",
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Customization Card
                    GestureDetector(
                      onTap: () => context.push('/customization'),
                      child: NeumorphicCardWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),

                    // Appearance Mode Toggle
                    NeumorphicCardWidget(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Appearance Mode",
                            style: TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          NeumorphicToggle(
                            height: 32,
                            width: 140,
                            selectedIndex: isDark ? 0 : 1,
                            thumb: Neumorphic(
                              style: NeumorphicStyle(
                                depth: 4,
                                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(8)),
                                color: accent,
                              ),
                            ),
                            style: const NeumorphicToggleStyle(
                              backgroundColor: Colors.transparent,
                            ),
                            children: [
                              ToggleElement(
                                background: Center(
                                  child: Text(
                                    "Dark",
                                    style: TextStyle(color: textPrimary, fontSize: 12),
                                  ),
                                ),
                                foreground: Center(
                                  child: Text(
                                    "Dark",
                                    style: TextStyle(
                                      color: isDark ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              ToggleElement(
                                background: Center(
                                  child: Text(
                                    "Light",
                                    style: TextStyle(color: textPrimary, fontSize: 12),
                                  ),
                                ),
                                foreground: Center(
                                  child: Text(
                                    "Light",
                                    style: TextStyle(
                                      color: !isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              controller.setThemeMode(val == 0 ? ThemeMode.dark : ThemeMode.light);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Currency Setting Card (Interactive Modal Selector)
                    GestureDetector(
                      onTap: () => _showCurrencyPicker(context, textPrimary, textSecondary, accent),
                      child: NeumorphicCardWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    "All receipts are automatically converted",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    const SizedBox(height: 12),

                    // Isar Database Viewer Card
                    GestureDetector(
                      onTap: () => context.push('/settings/db-viewer'),
                      child: NeumorphicCardWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    "Inspect stored receipts & Isar storage live",
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
              ),
            ),
          ),
        );
      },
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
                    children: CurrencyService.supportedCurrencies.entries.map((entry) {
                      final code = entry.key;
                      final info = entry.value;
                      final isSelected = code == CurrencyService.instance.currentCurrency;

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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final accent = controller.accentColor;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppBottomNavBar(currentPath: '/analytics'),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Spending Analytics",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Weekly Overview Card
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Weekly Overview",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Bar chart representation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBar(context, "Mon", 40, false),
                                _buildBar(context, "Tue", 70, false),
                                _buildBar(context, "Wed", 30, false),
                                _buildBar(context, "Thu", 110, true), // Peak
                                _buildBar(context, "Fri", 55, false),
                                _buildBar(context, "Sat", 85, false),
                                _buildBar(context, "Sun", 45, false),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Category Breakdown Card
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Top Categories",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CategoryRow(label: "🛒 Groceries", amount: "\$480.00", percentage: "40%", textPrimary: textPrimary, accent: accent),
                            const SizedBox(height: 12),
                            _CategoryRow(label: "🍔 Dining", amount: "\$300.00", percentage: "25%", textPrimary: textPrimary, accent: accent),
                            const SizedBox(height: 12),
                            _CategoryRow(label: "🚗 Transport", amount: "\$240.00", percentage: "20%", textPrimary: textPrimary, accent: accent),
                            const SizedBox(height: 12),
                            _CategoryRow(label: "🛍️ Shopping", amount: "\$180.00", percentage: "15%", textPrimary: textPrimary, accent: accent),
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

  Widget _buildBar(BuildContext context, String day, double height, bool isHighlighted) {
    final controller = AppThemeController.instance;
    final accent = controller.accentColor;
    final textSecondary = controller.secondaryTextColor;

    return Column(
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: isHighlighted ? accent : accent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final String amount;
  final String percentage;
  final Color textPrimary;
  final Color accent;

  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.textPrimary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: textPrimary),
        ),
        Text(
          "$amount ($percentage)",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent),
        ),
      ],
    );
  }
}


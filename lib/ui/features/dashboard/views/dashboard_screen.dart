import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppBottomNavBar(currentPath: '/dashboard'),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hello, Nino",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Here is your spending breakdown",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          NeumorphicIconBadge(
                            icon: Icons.person,
                            iconSize: 24,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Total Spent Card
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TOTAL SPENT THIS MONTH",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "\$1,248.50",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: NeumorphicButtonWidget(
                                onPressed: () {
                                  context.push('/scanner');
                                },
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Quick Scan Receipt",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section Header
                      Text(
                        "Recent Receipts",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Recent Receipts List
                      _buildReceiptItem(
                        context: context,
                        merchant: "Whole Foods Market",
                        subtitle: "Groceries • Today",
                        amount: "-\$42.80",
                        icon: Icons.shopping_bag_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptItem(
                        context: context,
                        merchant: "Chevron Gas Station",
                        subtitle: "Transport • Yesterday",
                        amount: "-\$35.00",
                        icon: Icons.local_gas_station_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptItem(
                        context: context,
                        merchant: "Starbucks Coffee",
                        subtitle: "Dining • July 28",
                        amount: "-\$8.45",
                        icon: Icons.coffee_rounded,
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

  Widget _buildReceiptItem({
    required BuildContext context,
    required String merchant,
    required String subtitle,
    required String amount,
    required IconData icon,
  }) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    return NeumorphicCardWidget(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          NeumorphicIconBadge(
            icon: icon,
            isInset: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


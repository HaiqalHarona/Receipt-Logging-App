import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
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
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Hello, Nino 👋",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Here is your spending breakdown",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          Neumorphic(
                            style: const NeumorphicStyle(
                              boxShape: NeumorphicBoxShape.circle(),
                              depth: 3,
                              color: AppTheme.darkAccentPinkishRed,
                            ),
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.darkAccentPinkishRed,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Total Spent Card
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: 5,
                          intensity: 0.6,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "TOTAL SPENT THIS MONTH",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkTextSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "\$1,248.50",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: NeumorphicButton(
                                  onPressed: () {
                                    context.push('/scanner');
                                  },
                                  style: NeumorphicStyle(
                                    color: AppTheme.darkAccentPinkishRed,
                                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Center(
                                      child: Text(
                                        "📷 Quick Scan Receipt",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section Header
                      const Text(
                        "Recent Receipts",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Recent Item 1
                      _buildReceiptItem(
                        merchant: "Whole Foods Market",
                        subtitle: "Groceries • Today",
                        amount: "-\$42.80",
                        icon: Icons.shopping_bag_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptItem(
                        merchant: "Chevron Gas Station",
                        subtitle: "Transport • Yesterday",
                        amount: "-\$35.00",
                        icon: Icons.local_gas_station_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildReceiptItem(
                        merchant: "Starbucks Coffee",
                        subtitle: "Dining • July 28",
                        amount: "-\$8.45",
                        icon: Icons.coffee_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const AppBottomNavBar(currentPath: '/dashboard'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItem({
    required String merchant,
    required String subtitle,
    required String amount,
    required IconData icon,
  }) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: 3,
        intensity: 0.5,
        color: AppTheme.darkCardBackground,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Neumorphic(
              style: const NeumorphicStyle(
                depth: -2,
                boxShape: NeumorphicBoxShape.circle(),
                color: AppTheme.darkBackground,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: AppTheme.darkAccentPinkishRed, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

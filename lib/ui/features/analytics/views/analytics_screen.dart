import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
                      const Text(
                        "Spending Analytics",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Weekly Overview Card
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Weekly Overview",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Bar chart representation
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildBar("Mon", 40, false),
                                  _buildBar("Tue", 70, false),
                                  _buildBar("Wed", 30, false),
                                  _buildBar("Thu", 110, true), // Peak
                                  _buildBar("Fri", 55, false),
                                  _buildBar("Sat", 85, false),
                                  _buildBar("Sun", 45, false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Category Breakdown Card
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Top Categories",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                              SizedBox(height: 16),
                              _CategoryRow(label: "🛒 Groceries", amount: "\$480.00", percentage: "40%"),
                              SizedBox(height: 12),
                              _CategoryRow(label: "🍔 Dining", amount: "\$300.00", percentage: "25%"),
                              SizedBox(height: 12),
                              _CategoryRow(label: "🚗 Transport", amount: "\$240.00", percentage: "20%"),
                              SizedBox(height: 12),
                              _CategoryRow(label: "🛍️ Shopping", amount: "\$180.00", percentage: "15%"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppBottomNavBar(currentPath: '/history'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(String day, double height, bool isHighlighted) {
    return Column(
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.darkAccentPinkishRed : AppTheme.darkAccentPinkishRed.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.darkTextSecondary,
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

  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.darkTextPrimary),
        ),
        Text(
          "$amount ($percentage)",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkAccentPinkishRed),
        ),
      ],
    );
  }
}

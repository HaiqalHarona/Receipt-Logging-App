// File: lib/ui/features/dashboard/views/dashboard_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../view_models/dashboard_view_model.dart';
import 'widgets/monthly_spending_graph_card.dart';
import 'widgets/spending_summary_card.dart';
import 'widgets/recent_transactions_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardViewModel _viewModel = DashboardViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppThemeController.instance, _viewModel]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            bottomNavigationBar: const AppBottomNavBar(currentPath: '/dashboard'),
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16),
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
                              icon: Icons.qr_code_scanner_rounded,
                              iconSize: 22,
                              onTap: () => context.push('/scanner'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Monthly Spending Line Graph
                        MonthlySpendingGraphCard(
                          viewModel: _viewModel,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          accent: accent,
                        ),
                        const SizedBox(height: 20),

                        // Total Spent This Month Card (Live DB + Currency)
                        SpendingSummaryCard(
                          viewModel: _viewModel,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          accent: accent,
                        ),
                        const SizedBox(height: 28),

                        // Recent Receipts Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recent Receipts",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/history'),
                              child: Text(
                                "See All",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  // Dynamic Recent Receipts List — scrolls independently
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                      child: RecentTransactionsList(
                        viewModel: _viewModel,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accent: accent,
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
}

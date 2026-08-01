// File: lib/ui/features/dashboard/views/widgets/spending_summary_card.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../view_models/dashboard_view_model.dart';

/// Neumorphic Summary Card displaying real-time aggregated spending for the month
/// formatted in the user's selected active currency.
class SpendingSummaryCard extends StatelessWidget {
  final DashboardViewModel viewModel;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const SpendingSummaryCard({
    super.key,
    required this.viewModel,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicCardWidget(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL SPENT THIS MONTH",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  viewModel.currentCurrencyCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            viewModel.formattedTotalSpent,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tally from ledger (${viewModel.recentTransactions.length}+ transactions)",
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

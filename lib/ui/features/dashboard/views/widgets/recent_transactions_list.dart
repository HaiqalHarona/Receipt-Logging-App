// File: lib/ui/features/dashboard/views/widgets/recent_transactions_list.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../view_models/dashboard_view_model.dart';

/// Modular List Widget rendering recent receipts from [DashboardViewModel],
/// automatically formatted with currency conversion.
class RecentTransactionsList extends StatelessWidget {
  final DashboardViewModel viewModel;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const RecentTransactionsList({
    super.key,
    required this.viewModel,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final list = viewModel.recentTransactions;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            "No receipts logged yet.\nTap the camera button to scan one!",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final receipt = list[index];
        final formattedPrice = viewModel.formatReceiptPrice(receipt);

        return NeumorphicCardWidget(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Neumorphic(
                style: NeumorphicStyle(
                  depth: -2,
                  intensity: 0.8,
                  color: NeumorphicTheme.baseColor(context),
                  boxShape: const NeumorphicBoxShape.circle(),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _getCategoryIcon(receipt.category),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.merchant,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${receipt.category} • ${receipt.date}",
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedPrice,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('Groceries')) return Icons.local_grocery_store_rounded;
    if (cat.contains('Dining')) return Icons.fastfood_rounded;
    if (cat.contains('Transport')) return Icons.directions_car_rounded;
    if (cat.contains('Electronics')) return Icons.phone_iphone_rounded;
    if (cat.contains('Shopping')) return Icons.shopping_bag_rounded;
    return Icons.receipt_long_rounded;
  }
}

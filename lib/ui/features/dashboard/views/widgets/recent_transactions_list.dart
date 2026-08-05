// File: lib/ui/features/dashboard/views/widgets/recent_transactions_list.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../history/views/widgets/receipt_list_item_widget.dart';
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

        return ReceiptListItemWidget(
          receipt: receipt,
          formattedPrice: formattedPrice,
          onTap: () => context.push('/receipt-detail', extra: receipt),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          accent: accent,
        );
      },
    );
  }
}

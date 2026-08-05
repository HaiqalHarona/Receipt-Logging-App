// File: lib/ui/features/history/views/widgets/receipt_list_item_widget.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../domain/models/receipt.dart';
import '../../../../core/theme/app_theme.dart';

/// Clean Receipt List Item Widget for [HistoryScreen] supporting tap navigation to details.
class ReceiptListItemWidget extends StatelessWidget {
  final Receipt receipt;
  final String formattedPrice;
  final VoidCallback? onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const ReceiptListItemWidget({
    super.key,
    required this.receipt,
    required this.formattedPrice,
    this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeumorphicCardWidget(
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
                _getIcon(receipt.category),
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
      ),
    );
  }

  IconData _getIcon(String cat) {
    if (cat.contains('Groceries')) return Icons.local_grocery_store_rounded;
    if (cat.contains('Dining')) return Icons.fastfood_rounded;
    if (cat.contains('Transport')) return Icons.directions_car_rounded;
    if (cat.contains('Electronics')) return Icons.phone_iphone_rounded;
    if (cat.contains('Shopping')) return Icons.shopping_bag_rounded;
    return Icons.receipt_long_rounded;
  }
}

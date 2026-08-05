// File: lib/ui/features/history/views/widgets/receipt_list_item_widget.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../domain/models/receipt.dart';
import '../../../../core/utils/category_utils.dart';

/// Clean, uniform Receipt List Item Widget for [HistoryScreen] supporting tap navigation to details.
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
    final cleanCategory = CategoryUtils.sanitize(receipt.category);
    final categoryColor = CategoryUtils.getCategoryColor(cleanCategory);
    final categoryIcon = CategoryUtils.getCategoryIcon(cleanCategory);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 3,
          intensity: 0.8,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
        ),
        child: SizedBox(
          height: 76,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Uniquely colour-coded category icon badge
                Neumorphic(
                  style: NeumorphicStyle(
                    depth: -2,
                    intensity: 0.8,
                    color: categoryColor.withAlpha(25),
                    boxShape: const NeumorphicBoxShape.circle(),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    categoryIcon,
                    color: categoryColor,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                // Merchant & Category Badge + Date
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Colour-coded Category Pill Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: categoryColor.withAlpha(120),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              cleanCategory,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "• ${receipt.date}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Formatted Amount
                Text(
                  formattedPrice,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

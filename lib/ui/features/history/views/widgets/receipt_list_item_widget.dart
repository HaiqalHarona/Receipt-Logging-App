// File: lib/ui/features/history/views/widgets/receipt_list_item_widget.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../domain/models/receipt.dart';
import '../../../../core/utils/category_utils.dart';

/// Clean, uniform Receipt List Item Widget for [HistoryScreen] supporting tap navigation to details.
///
/// Layout:
/// - Left: Uniquely colour-coded category icon badge
/// - Center: Merchant title (top) & max 2 category pill tags + neutral +X overflow badge (bottom)
/// - Right: Amount spent (top right) & transaction date (bottom right)
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
    final allTags = receipt.category
        .split(',')
        .map((c) => CategoryUtils.sanitize(c).trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final primaryTag = allTags.isNotEmpty ? allTags.first : '';
    final primaryColor = CategoryUtils.getCategoryColor(primaryTag);
    final categoryIcon = CategoryUtils.getCategoryIcon(primaryTag);

    final displayTags = allTags.take(2).toList();
    final remainingCount = allTags.length > 2 ? allTags.length - 2 : 0;

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
                // Uniquely colour-coded primary category icon badge (Left)
                Neumorphic(
                  style: NeumorphicStyle(
                    depth: -2,
                    intensity: 0.8,
                    color: primaryColor.withAlpha(25),
                    boxShape: const NeumorphicBoxShape.circle(),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    categoryIcon,
                    color: primaryColor,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                // Merchant Title & Category Badges (Center)
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
                          ...displayTags.map((tag) {
                            final tagColor = CategoryUtils.getCategoryColor(tag);
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tagColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: tagColor.withAlpha(120),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tagColor,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (remainingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: textSecondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+$remainingCount',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount Spent (Top Right) & Date (Bottom Right)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedPrice,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receipt.date,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reciept_logging/core/theme/app_theme.dart';
import 'package:reciept_logging/core/theme/app_colors.dart';
import 'package:reciept_logging/core/widgets/neu_card.dart';
import 'package:reciept_logging/core/widgets/amount_display.dart';
import 'package:reciept_logging/core/providers/isar_provider.dart';
import 'package:reciept_logging/models/receipt.dart';

final receiptByIdProvider = FutureProvider.family<Receipt?, int>((ref, id) async {
  final isar = await ref.watch(isarProvider.future);
  return isar.receipts.get(id);
});

class ReceiptDetailScreen extends ConsumerWidget {
  final int receiptId;
  const ReceiptDetailScreen({super.key, required this.receiptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptAsync = ref.watch(receiptByIdProvider(receiptId));

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: AppTheme.lightBackground,
        appBar: NeumorphicAppBar(
          title: const Text('Receipt Detail'),
          leading: NeumorphicButton(
            style: const NeumorphicStyle(boxShape: NeumorphicBoxShape.circle()),
            padding: const EdgeInsets.all(8),
            onPressed: () => context.pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        body: receiptAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (receipt) {
            if (receipt == null) {
              return const Center(child: Text('Receipt not found'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                receipt.merchantName,
                                style: AppTheme.headlineMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.getCategoryColor(receipt.category).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                receipt.category,
                                style: AppTheme.labelSmall.copyWith(
                                  color: AppColors.getCategoryColor(receipt.category),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AmountDisplay(amount: receipt.totalAmount, large: true),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(receipt.date),
                          style: AppTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (receipt.rawOcrText.isNotEmpty)
                    NeuCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Raw OCR Text', style: AppTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text(
                            receipt.rawOcrText.join('\n'),
                            style: AppTheme.bodyMedium.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

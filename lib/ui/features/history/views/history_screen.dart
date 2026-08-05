// File: lib/ui/features/history/views/history_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../view_models/history_view_model.dart';
import 'widgets/receipt_list_item_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryViewModel _viewModel = HistoryViewModel();

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

        final list = _viewModel.receipts;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            bottomNavigationBar: const AppBottomNavBar(currentPath: '/history'),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Receipt History",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "All logged transactions (${list.length} records)",
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (list.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            "No receipts in your ledger.\nScan a receipt to start building your history!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final receipt = list[index];
                          final formattedPrice = _viewModel.formatReceiptPrice(receipt);

                          return ReceiptListItemWidget(
                            receipt: receipt,
                            formattedPrice: formattedPrice,
                            onTap: () => context.push('/receipt-detail', extra: receipt),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

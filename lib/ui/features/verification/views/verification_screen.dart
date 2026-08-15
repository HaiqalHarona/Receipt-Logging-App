// File: lib/ui/features/verification/views/verification_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../domain/models/receipt.dart';
import '../view_models/verification_view_model.dart';
import 'widgets/verification_card_widget.dart';

/// Data Verification & Review Screen
/// Supports single receipt review or multi-receipt bulk review carousel
/// before committing extracted transactions to the local Isar database.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final VerificationViewModel _viewModel = VerificationViewModel();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      Object? extra;
      try {
        extra = GoRouterState.of(context).extra;
      } catch (_) {
        extra = null;
      }
      List<Receipt> initialList = [];

      if (extra is List<Receipt> && extra.isNotEmpty) {
        initialList = extra;
      } else if (extra is List && extra.isNotEmpty) {
        // Backwards compatibility with Map payloads
        initialList = extra
            .map((item) {
              if (item is Receipt) return item;
              if (item is Map)
                return Receipt.fromJson(item.cast<String, dynamic>());
              return null;
            })
            .whereType<Receipt>()
            .toList();
      } else if (extra is Receipt) {
        initialList = [extra];
      } else {
        initialList = [];
      }

      _viewModel.setReceipts(initialList);
      _isInitialized = true;
    }
  }

  void _saveAll() {
    if (_viewModel.receipts.isEmpty) return;
    _viewModel.saveAllReceipts(() {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message:
            "Successfully saved ${_viewModel.receipts.length} receipt${_viewModel.receipts.length > 1 ? 's' : ''}!",
      );
      context.go('/dashboard');
    });
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

        final currentReceipt = _viewModel.currentReceipt;
        final totalCount = _viewModel.receipts.length;
        final currentIndex = _viewModel.currentIndex;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Center(
                child: NeumorphicIconBadge(
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 18,
                  onTap: () => context.pop(),
                ),
              ),
              title: Text(
                totalCount > 1
                    ? "Review Receipt (${currentIndex + 1} of $totalCount)"
                    : "Review Receipt",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    if (totalCount > 1)
                      _VerificationCarouselHeader(
                        currentIndex: currentIndex,
                        totalCount: totalCount,
                        accent: accent,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onPrevious: _viewModel.previousReceipt,
                        onNext: _viewModel.nextReceipt,
                      ),
                    if (totalCount == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            "No receipt data received.\nPlease scan a receipt or select an image to verify.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Editable Receipt Card
                      VerificationCardWidget(
                        receipt: currentReceipt!,
                        onChanged: (updated) {
                          _viewModel.updateReceipt(updated);
                        },
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accent: accent,
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: NeumorphicButtonWidget(
                          onPressed: _viewModel.isSaving ? null : _saveAll,
                          child: Center(
                            child: _viewModel.isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    totalCount > 1
                                        ? "Save All $totalCount Receipts"
                                        : "Save Receipt",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: Text(
                          "Rescan / Take Another",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
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

/// Extracted Bulk Review Carousel Navigation Header Bar
class _VerificationCarouselHeader extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _VerificationCarouselHeader({
    required this.currentIndex,
    required this.totalCount,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeumorphicCardWidget(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: currentIndex > 0
                    ? accent
                    : textSecondary.withValues(alpha: 0.3),
              ),
              onPressed: currentIndex > 0 ? onPrevious : null,
            ),
            Text(
              "Receipt ${currentIndex + 1} / $totalCount",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: currentIndex < totalCount - 1
                    ? accent
                    : textSecondary.withValues(alpha: 0.3),
              ),
              onPressed: currentIndex < totalCount - 1 ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

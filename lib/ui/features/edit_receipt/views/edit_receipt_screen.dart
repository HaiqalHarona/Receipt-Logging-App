// File: lib/ui/features/edit_receipt/views/edit_receipt_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/fading_edge_scroll_view.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../cloud/services/quota_service.dart';
import '../../verification/views/widgets/verification_card_widget.dart';

/// A dedicated screen for editing an existing saved receipt.
///
/// Unlike [VerificationScreen] (which is for reviewing newly-scanned receipts
/// before saving), this screen edits an already-persisted receipt and persists
/// changes back to Isar + Supabase immediately when the user taps Save.
///
/// It does NOT include bulk carousel navigation or the "Rescan / Take Another" link.
class EditReceiptScreen extends StatefulWidget {
  const EditReceiptScreen({super.key});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  Receipt? _receipt;
  Receipt? _editedReceipt;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Receipt) {
        _receipt = extra;
        _editedReceipt = extra;
      }
      _isInitialized = true;
    }
  }

  Future<void> _save() async {
    if (_editedReceipt == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ReceiptRepository.instance.updateReceipt(_editedReceipt!);
      if (!mounted) return;
      AppSnackBar.show(context, message: 'Receipt saved successfully!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context,
          message: 'Failed to save receipt. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return AppGradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Standardized Custom Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NeumorphicCircularButton(
                          icon: Icons.arrow_back_rounded,
                          iconSize: 20,
                          onTap: () => context.pop(),
                        ),
                        Text(
                          'Edit Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _receipt == null
                        ? Center(
                            child: Text(
                              'No receipt data to edit.',
                              style: TextStyle(
                                  fontSize: 14, color: textSecondary),
                            ),
                          )
                        : FadingEdgeScrollView(
                            fadeHeightTop: 20,
                            fadeHeightBottom: 28,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              child: Column(
                                children: [
                                  // Editable Receipt Card
                                  VerificationCardWidget(
                                    key: ValueKey(_receipt!.id),
                                    receipt: _editedReceipt!,
                                    onChanged: (updated) {
                                      setState(() => _editedReceipt = updated);
                                    },
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                    accent: accent,
                                    isPremium: QuotaService.instance.isPremium,
                                  ),
                                  const SizedBox(height: 32),

                                  // Save Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: NeumorphicButtonWidget(
                                      onPressed: _isSaving ? null : _save,
                                      child: Center(
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'Save Receipt',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
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

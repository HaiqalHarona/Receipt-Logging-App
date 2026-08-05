// File: lib/ui/features/receipt_detail/views/receipt_detail_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../verification/views/widgets/verification_card_widget.dart';

/// Receipt Detail Screen allowing viewing, editing, line item management,
/// saving updates, and deleting an existing receipt record.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  Receipt? _receipt;
  late Receipt _editedReceipt;
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

      if (extra is Receipt) {
        _receipt = extra;
      } else if (extra is Map) {
        _receipt = Receipt.fromJson(extra.cast<String, dynamic>());
      }

      if (_receipt != null) {
        _editedReceipt = _receipt!;
      }
      _isInitialized = true;
    }
  }

  void _saveChanges() async {
    await ReceiptRepository.instance.saveReceipt(_editedReceipt);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt updated successfully!'),
        backgroundColor: AppThemeController.instance.accentColor,
      ),
    );
    context.pop();
  }

  void _confirmDelete() {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 4,
            intensity: 0.8,
            color: controller.currentBaseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Delete Receipt?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this receipt from your ledger? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: NeumorphicStyle(
                          depth: 3,
                          color: controller.currentBaseColor,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          if (_receipt != null) {
                            await ReceiptRepository.instance.deleteReceipt(_receipt!.id);
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Receipt deleted.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          context.pop();
                        },
                        style: NeumorphicStyle(
                          depth: 3,
                          color: Colors.red.shade400,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        if (_receipt == null) {
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
                  'Receipt Details',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              body: Center(
                child: Text('No receipt selected.', style: TextStyle(color: textSecondary)),
              ),
            ),
          );
        }

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
                'Receipt Details',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: NeumorphicButton(
                      onPressed: _confirmDelete,
                      style: NeumorphicStyle(
                        depth: 3,
                        boxShape: const NeumorphicBoxShape.circle(),
                        color: controller.currentBaseColor,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: VerificationCardWidget(
                        receipt: _editedReceipt,
                        onChanged: (updated) {
                          setState(() => _editedReceipt = updated);
                        },
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accent: accent,
                      ),
                    ),
                  ),

                  // Bottom Action Buttons (Save Changes)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: NeumorphicButton(
                            onPressed: _saveChanges,
                            style: NeumorphicStyle(
                              depth: 4,
                              intensity: 0.85,
                              color: accent,
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Text(
                              'Save Changes',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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

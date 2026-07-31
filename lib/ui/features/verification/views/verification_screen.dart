// File: lib/ui/features/verification/views/verification_screen.dart
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// Data Verification & Review Screen
/// Supports single receipt review or multi-receipt bulk review carousel
/// before committing extracted transactions to the Isar local DB & backend.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _receipts = [];
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is List<Map<String, dynamic>> && extra.isNotEmpty) {
        _receipts = List.from(extra);
      } else if (extra is Map<String, dynamic>) {
        _receipts = [extra];
      } else {
        _receipts = [
          {
            "merchant": "Whole Foods Market",
            "date": "Aug 01, 2026",
            "amount": "\$42.80",
            "category": "Groceries 🛒",
          },
        ];
      }
      _isInitialized = true;
    }
  }

  void _nextReceipt() {
    if (_currentIndex < _receipts.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _previousReceipt() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _saveAllReceipts() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Successfully saved ${_receipts.length} receipt${_receipts.length > 1 ? 's' : ''} to ledger!",
        ),
        backgroundColor: AppThemeController.instance.accentColor,
      ),
    );
    context.go('/dashboard');
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

        final currentReceipt = _receipts[_currentIndex];
        final totalCount = _receipts.length;

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
                    ? "Review Receipt (${_currentIndex + 1} of $totalCount)"
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (totalCount > 1)
                      _VerificationCarouselHeader(
                        currentIndex: _currentIndex,
                        totalCount: totalCount,
                        accent: accent,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onPrevious: _previousReceipt,
                        onNext: _nextReceipt,
                      ),
                    _VerificationInputField(
                      label: "MERCHANT NAME",
                      initialValue: currentReceipt["merchant"] ?? "Unknown Merchant",
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 18),
                    _VerificationInputField(
                      label: "DATE",
                      initialValue: currentReceipt["date"] ?? "Aug 01, 2026",
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 18),
                    _VerificationInputField(
                      label: "TOTAL AMOUNT",
                      initialValue: currentReceipt["amount"] ?? "\$0.00",
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 18),
                    _VerificationInputField(
                      label: "CATEGORY",
                      initialValue: currentReceipt["category"] ?? "General 🧾",
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: NeumorphicButtonWidget(
                        onPressed: _saveAllReceipts,
                        child: Center(
                          child: Text(
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

/// Extracted Neumorphic Field Display Component
class _VerificationInputField extends StatelessWidget {
  final String label;
  final String initialValue;
  final Color textPrimary;
  final Color textSecondary;

  const _VerificationInputField({
    required this.label,
    required this.initialValue,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        NeumorphicInputFieldWidget(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              initialValue,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

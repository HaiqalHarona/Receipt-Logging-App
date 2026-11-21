// File: lib/ui/core/widgets/neumorphic_loading_barrier.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../theme/theme_controller.dart';

/// A non-interactive, full-screen dimmed overlay dialog that blocks user interaction
/// while an asynchronous operation is in progress.
class NeumorphicLoadingBarrier extends StatelessWidget {
  final String message;

  const NeumorphicLoadingBarrier({
    super.key,
    this.message = 'Sending verification code...',
  });

  /// Displays an un-dismissible loading barrier dialog, executes [action],
  /// and guarantees the barrier is dismissed in a `finally` block before returning
  /// the result or re-throwing any error.
  static Future<T> runWithBarrier<T>(
    BuildContext context, {
    required Future<T> Function() action,
    String message = 'Sending verification code...',
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    bool dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: NeumorphicLoadingBarrier(message: message),
        );
      },
    ).then((_) {
      dialogOpen = false;
    });

    try {
      return await action();
    } finally {
      if (dialogOpen && navigator.mounted) {
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final baseColor = controller.currentBaseColor;
    final accentColor = controller.accentColor;
    final primaryTextColor = controller.textColor;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 4,
              intensity: 0.85,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
              color: baseColor,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// File: lib/ui/core/widgets/scan_progress_snack_bar.dart
//
// Persistent SnackBar for async bulk scan progress.
//
// States:
//   scanning  — spinner icon, progress text, 'Cancel' + 'X' buttons
//   complete  — check icon, completion text, 'Review' + 'X' buttons
//   error     — error icon, error message, optional 'Retry' + 'X' buttons

import 'package:flutter/material.dart';
import '../router/app_router.dart';
import '../theme/theme_controller.dart';

// ignore_for_file: use_build_context_synchronously

/// Displays a persistent scan progress SnackBar at the bottom of the screen.
/// Uses [rootScaffoldMessengerKey] so that presentation works from any service
/// or callback without depending on screen widget lifecycles.
class ScanProgressSnackBar {
  ScanProgressSnackBar._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Shows the **scanning** state SnackBar.
  ///
  /// [onCancel] — called when the user taps 'Cancel'. Closes the SSE stream.
  static void show({
    BuildContext? context,
    required String message,
    required VoidCallback onCancel,
  }) {
    _present(
      _ScanSnackBarConfig.scanning(message: message, onCancel: onCancel),
      context: context,
    );
  }

  /// Updates SnackBar to the **complete** state.
  ///
  /// [onReview] — called when the user taps 'Review'. Navigates to /verification.
  static void showComplete({
    BuildContext? context,
    required String message,
    required VoidCallback onReview,
  }) {
    _present(
      _ScanSnackBarConfig.complete(message: message, onReview: onReview),
      context: context,
    );
  }

  /// Shows the **error** state SnackBar.
  ///
  /// [onRetry] — optional retry callback. If null, no Retry button is shown.
  static void showError({
    BuildContext? context,
    required String message,
    VoidCallback? onRetry,
  }) {
    _present(
      _ScanSnackBarConfig.error(message: message, onRetry: onRetry),
      context: context,
    );
  }

  static void dismiss({BuildContext? context}) {
    final messenger = (context != null && context.mounted)
        ? ScaffoldMessenger.of(context)
        : rootScaffoldMessengerKey.currentState;
    messenger?.removeCurrentSnackBar();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static void _present(_ScanSnackBarConfig config, {BuildContext? context}) {
    final messenger = (context != null && context.mounted)
        ? ScaffoldMessenger.of(context)
        : rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    // Immediately remove existing SnackBar to instantly transition without animation delay
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        // Persist indefinitely — user must dismiss explicitly.
        duration: const Duration(days: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: _ScanProgressSnackBarWidget(config: config),
      ),
    );
  }
}

// ── Config ─────────────────────────────────────────────────────────────────────

enum _ScanState { scanning, complete, error }

class _ScanSnackBarConfig {
  const _ScanSnackBarConfig({
    required this.state,
    required this.message,
    this.onCancel,
    this.onReview,
    this.onRetry,
  });

  factory _ScanSnackBarConfig.scanning({
    required String message,
    required VoidCallback onCancel,
  }) =>
      _ScanSnackBarConfig(state: _ScanState.scanning, message: message, onCancel: onCancel);

  factory _ScanSnackBarConfig.complete({
    required String message,
    required VoidCallback onReview,
  }) =>
      _ScanSnackBarConfig(state: _ScanState.complete, message: message, onReview: onReview);

  factory _ScanSnackBarConfig.error({
    required String message,
    VoidCallback? onRetry,
  }) =>
      _ScanSnackBarConfig(state: _ScanState.error, message: message, onRetry: onRetry);

  final _ScanState state;
  final String message;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;
  final VoidCallback? onRetry;

  bool get isScanning => state == _ScanState.scanning;
  bool get isComplete => state == _ScanState.complete;
  bool get isError => state == _ScanState.error;
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class _ScanProgressSnackBarWidget extends StatefulWidget {
  const _ScanProgressSnackBarWidget({required this.config});
  final _ScanSnackBarConfig config;

  @override
  State<_ScanProgressSnackBarWidget> createState() => _ScanProgressSnackBarWidgetState();
}

class _ScanProgressSnackBarWidgetState extends State<_ScanProgressSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.config.isScanning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final controller = AppThemeController.instance;

    final Color bg = config.isError
        ? Colors.red.shade900
        : (controller.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E));
    final Color accent = config.isError
        ? Colors.redAccent
        : config.isComplete
            ? Colors.greenAccent.shade400
            : controller.accentColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 6, top: 10, bottom: 10),
              child: Row(
                children: [
                  // Leading icon
                  _LeadingIcon(config: config, pulseController: _pulseController, accent: accent),
                  const SizedBox(width: 10),

                  // Message
                  Expanded(
                    child: Text(
                      config.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Action button: Cancel / Review / Retry
                  _ActionButton(config: config, accent: accent, context: context),

                  // Close 'X' button
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => ScaffoldMessenger.of(context).removeCurrentSnackBar(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom indicator line: pulsing for scanning, solid for complete/error
            _BottomIndicator(config: config, accent: accent, pulseController: _pulseController),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({
    required this.config,
    required this.pulseController,
    required this.accent,
  });

  final _ScanSnackBarConfig config;
  final AnimationController pulseController;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (config.isScanning) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(accent),
        ),
      );
    }
    if (config.isComplete) {
      return Icon(Icons.check_circle_outline_rounded, color: accent, size: 20);
    }
    return Icon(Icons.error_outline_rounded, color: accent, size: 20);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.config,
    required this.accent,
    required this.context,
  });

  final _ScanSnackBarConfig config;
  final Color accent;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    String? label;
    VoidCallback? handler;

    if (config.isScanning && config.onCancel != null) {
      label = 'Cancel';
      handler = () {
        config.onCancel!();
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      };
    } else if (config.isComplete && config.onReview != null) {
      label = 'Review';
      handler = () {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        config.onReview!();
      };
    } else if (config.isError && config.onRetry != null) {
      label = 'Retry';
      handler = () {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        config.onRetry!();
      };
    }

    if (label == null || handler == null) return const SizedBox.shrink();

    return TextButton(
      onPressed: handler,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _BottomIndicator extends StatelessWidget {
  const _BottomIndicator({
    required this.config,
    required this.accent,
    required this.pulseController,
  });

  final _ScanSnackBarConfig config;
  final Color accent;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    if (config.isScanning) {
      // Animated indeterminate shimmer line
      return AnimatedBuilder(
        animation: pulseController,
        builder: (ctx, _) {
          final t = pulseController.value; // 0.0 → 1.0 → 0.0
          return Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  accent.withValues(alpha: 0.1),
                  accent.withValues(alpha: t),
                  accent.withValues(alpha: 0.1),
                ],
                stops: [0.0, t, 1.0],
              ),
            ),
          );
        },
      );
    }

    // Static solid indicator for complete / error
    return Container(height: 3, color: accent);
  }
}

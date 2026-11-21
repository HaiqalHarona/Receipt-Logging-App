import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/theme_controller.dart';

/// Shows a warning modal informing the user that existing guest data cannot be
/// merged into an existing account and will be purged if confirmed.
///
/// Returns true if the user typed "Override Data" and confirmed, false otherwise.
Future<bool> showGuestOverrideWarningModal(BuildContext context) async {
  final controller = AppThemeController.instance;
  final textPrimary = controller.textColor;
  final textSecondary = controller.secondaryTextColor;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      String inputText = '';
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final canOverride = inputText.trim() == 'Override Data';
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: 0,
                boxShape:
                    NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
                color: NeumorphicTheme.baseColor(dialogContext),
                border:
                    NeumorphicBorder(color: Colors.red.shade700, width: 2.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Warning",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Cannot migrate local receipts, settings, and other data into an existing account. If you wish to save these data, please create a new account.",
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "To confirm data override, type 'Override Data' below (case-sensitive):",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: -3,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(10)),
                        color: NeumorphicTheme.baseColor(dialogContext),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: TextField(
                          onChanged: (val) {
                            setDialogState(() {
                              inputText = val;
                            });
                          },
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Override Data',
                            hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            disabledBackgroundColor:
                                Colors.red.shade900.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white38,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: canOverride
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: Colors.red.shade900, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onPressed: canOverride
                              ? () => Navigator.of(ctx).pop(true)
                              : null,
                          child: const Text(
                            "Override Data",
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return result ?? false;
}

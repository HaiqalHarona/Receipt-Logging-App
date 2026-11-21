// File: lib/ui/core/widgets/trial_ineligible_dialog.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// A modal dialog presented after email verification when the user, device,
/// or email is ineligible for the 14-day reverse trial.
class TrialIneligibleDialog extends StatelessWidget {
  final String title;
  final String message;

  const TrialIneligibleDialog({
    super.key,
    this.title = 'Trial Ineligible',
    this.message =
        'This device or email address has already been used for a free trial or active subscription. Your account has been set to the Free plan.',
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Trial Ineligible',
    String message =
        'This device or email address has already been used for a free trial or active subscription. Your account has been set to the Free plan.',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => TrialIneligibleDialog(
        title: title,
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 8,
          intensity: 0.85,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          color: controller.currentBaseColor,
          border: NeumorphicBorder(
            color: accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Info Icon ──
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 30,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Title ──
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // ── Description ──
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // ── View Plans Button ──
              SizedBox(
                width: double.infinity,
                child: NeumorphicButtonWidget(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/paywall');
                  },
                  color: accent,
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text(
                      'View Plans',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Continue on Free Tier Button ──
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Continue on Free Tier',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

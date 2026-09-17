// File: lib/ui/core/widgets/account_required_dialog.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_controller.dart';

/// A modal dialog presented to unauthenticated guest users when they attempt
/// to access features, subscriptions, or settings that require a registered account.
class AccountRequiredDialog extends StatelessWidget {
  final String title;
  final String message;

  const AccountRequiredDialog({
    super.key,
    this.title = 'Account Required',
    this.message =
        'This feature requires an account. Sign in or register to unlock unlimited access, cloud backups, and subscription plans.',
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Account Required',
    String message =
        'This feature requires an account. Sign in or register to unlock unlimited access, cloud backups, and subscription plans.',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AccountRequiredDialog(
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
              // ── Lock Icon ──
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
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

              // ── Sign In / Register Button ──
              SizedBox(
                width: double.infinity,
                child: NeumorphicButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/auth');
                  },
                  style: NeumorphicStyle(
                    color: accent,
                    depth: 4,
                    intensity: 0.8,
                    boxShape: NeumorphicBoxShape.roundRect(
                      BorderRadius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text(
                      'Sign In / Register',
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

              // ── Cancel / Dismiss Button ──
              SizedBox(
                width: double.infinity,
                child: NeumorphicButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: NeumorphicStyle(
                    color: controller.currentBaseColor,
                    depth: 2,
                    boxShape: NeumorphicBoxShape.roundRect(
                      BorderRadius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Maybe Later',
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

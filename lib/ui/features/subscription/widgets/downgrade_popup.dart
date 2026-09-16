import 'dart:math';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../constants/subscription_constants.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/subscription_models.dart';
import '../../../../cloud/services/auth_service.dart';
import '../views/premium_paywall_sheet.dart';

class DowngradePopupHelper {
  DowngradePopupHelper._();

  /// Evaluates trial expiration and discount reminder schedules.
  /// Shows Day 15 downgrade dialog, Day 1 reminder, or Day 5 reminder as appropriate.
  static Future<void> checkAndShow(BuildContext context) async {
    if (!AuthService.instance.isLoggedIn) return;
    final userId = AuthService.instance.currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      final stats = await BackendApiClient.instance.getUserStats();

      // Only applicable if user completed a trial and is now on free tier
      final hasHadTrial = stats.trialStartAt != null;
      final isFreeTier = stats.tier == 'free';
      if (!hasHadTrial || !isFreeTier) return;

      final prefs = await SharedPreferences.getInstance();
      final keyDay15 = 'downgrade_day15_popup_shown_$userId';
      final keyDay1Reminder = 'downgrade_reminder_day1_shown_$userId';
      final keyDay5Reminder = 'downgrade_reminder_day5_shown_$userId';

      final day15Shown = prefs.getBool(keyDay15) ?? false;
      if (!day15Shown) {
        await prefs.setBool(keyDay15, true);
        if (!context.mounted) return;
        AppLogger.info('DowngradePopup', 'Showing Day 15 downgrade dialog for user $userId');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => DowngradeDay15Dialog(stats: stats),
        );
        return;
      }

      // Check for Day 1 and Day 5 reminder popups within the 7-day discount window
      final discountShownAt = stats.discountOfferShownAt;
      if (discountShownAt != null) {
        final daysElapsed = DateTime.now().difference(discountShownAt).inDays;
        final daysRemaining = max(1, SubscriptionConstants.downgradeDiscountDays - daysElapsed);

        if (daysElapsed >= 1 && daysElapsed < 5) {
          final day1Shown = prefs.getBool(keyDay1Reminder) ?? false;
          if (!day1Shown) {
            await prefs.setBool(keyDay1Reminder, true);
            if (!context.mounted) return;
            AppLogger.info('DowngradePopup', 'Showing Day 1 discount reminder for user $userId');
            await showDialog(
              context: context,
              builder: (ctx) => DowngradeReminderDialog(
                dayNumber: 1,
                daysRemaining: daysRemaining,
              ),
            );
          }
        } else if (daysElapsed >= 5 && daysElapsed <= 7) {
          final day5Shown = prefs.getBool(keyDay5Reminder) ?? false;
          if (!day5Shown) {
            await prefs.setBool(keyDay5Reminder, true);
            if (!context.mounted) return;
            AppLogger.info('DowngradePopup', 'Showing Day 5 discount reminder for user $userId');
            await showDialog(
              context: context,
              builder: (ctx) => DowngradeReminderDialog(
                dayNumber: 5,
                daysRemaining: daysRemaining,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.warning('DowngradePopup', 'Error evaluating downgrade popup: $e');
    }
  }
}

/// Day 15 Downgrade Dialog informing user about their saved data,
/// time saved with fast AI, Free tier quotas, and the 7-day downgrade discount.
class DowngradeDay15Dialog extends StatelessWidget {
  final UserStatsDto stats;

  const DowngradeDay15Dialog({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final amberColor = Colors.amber.shade600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 0,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(22)),
          color: NeumorphicTheme.baseColor(context),
          border: NeumorphicBorder(
            color: accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: accent,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Message
              Text(
                "Your Premium Trial Has Ended",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You have been switched to the Free plan. Rest assured, all your data and scanned receipts are 100% safe!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // ── Stats Summary Card ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: controller.currentBaseColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              color: accent, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            "${stats.totalReceipts}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Receipts Saved",
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: controller.currentBaseColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.bolt_rounded,
                              color: amberColor, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            "${stats.timeSavedMinutes.toStringAsFixed(1)}m",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Time Saved (AI)",
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Downgrade Discount Offer Banner ─────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrangeAccent.withValues(alpha: 0.18),
                      amberColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.deepOrangeAccent.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          "Special 7-Day Downgrade Offer",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "• 1 Month Free on monthly plan (\$5.99/mo)\n• 3 Months Free on annual plan (\$3.99/mo)\n⏳ Offer expires in 7 days!",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Primary Action CTA ──────────────────────────────────────
              SizedBox(
                height: 48,
                child: NeumorphicButtonWidget(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showPremiumPaywallSheet(context);
                  },
                  child: const Center(
                    child: Text(
                      "View Discount Offer",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary Dismiss Action
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Continue with Free Plan",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
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

/// Reminder Dialog for Day 1 or Day 5 after downgrade.
class DowngradeReminderDialog extends StatelessWidget {
  final int dayNumber;
  final int daysRemaining;

  const DowngradeReminderDialog({
    super.key,
    required this.dayNumber,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    final isFinal = dayNumber >= 5;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 0,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          color: NeumorphicTheme.baseColor(context),
          border: NeumorphicBorder(
            color: isFinal
                ? Colors.deepOrangeAccent.withValues(alpha: 0.5)
                : accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (isFinal ? Colors.deepOrangeAccent : accent)
                        .withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFinal
                        ? Icons.timer_outlined
                        : Icons.local_fire_department_rounded,
                    color: isFinal ? Colors.deepOrangeAccent : accent,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFinal
                    ? "Final Days: $daysRemaining Left!"
                    : "Don't Miss Out: $daysRemaining Days Left",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your exclusive discount on SancFund Premium is expiring soon. Get 1 month free (monthly) or 3 months free (annual) before it's gone!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: NeumorphicButtonWidget(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showPremiumPaywallSheet(context);
                  },
                  child: const Center(
                    child: Text(
                      "Claim Discount",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Dismiss",
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
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

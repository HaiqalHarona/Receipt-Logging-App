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
        final selectedPlan = await showDialog<PaywallPlanType>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => DowngradeDay15Dialog(stats: stats),
        );
        if (selectedPlan != null && context.mounted) {
          await showPremiumPaywallSheet(context, initialPlan: selectedPlan);
        }
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
            final shouldUpgrade = await showDialog<bool>(
              context: context,
              builder: (ctx) => DowngradeReminderDialog(
                dayNumber: 1,
                daysRemaining: daysRemaining,
              ),
            );
            if (shouldUpgrade == true && context.mounted) {
              await showPremiumPaywallSheet(context);
            }
          }
        } else if (daysElapsed >= 5 && daysElapsed <= 7) {
          final day5Shown = prefs.getBool(keyDay5Reminder) ?? false;
          if (!day5Shown) {
            await prefs.setBool(keyDay5Reminder, true);
            if (!context.mounted) return;
            AppLogger.info('DowngradePopup', 'Showing Day 5 discount reminder for user $userId');
            final shouldUpgrade = await showDialog<bool>(
              context: context,
              builder: (ctx) => DowngradeReminderDialog(
                dayNumber: 5,
                daysRemaining: daysRemaining,
              ),
            );
            if (shouldUpgrade == true && context.mounted) {
              await showPremiumPaywallSheet(context);
            }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 0,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(24)),
          color: NeumorphicTheme.baseColor(context),
          border: NeumorphicBorder(
            color: accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Visual Badge ─────────────────────────────────────
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.25),
                        amberColor.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: amberColor,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Status Pill ─────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: amberColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: amberColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 14, color: amberColor),
                      const SizedBox(width: 5),
                      Text(
                        "TRIAL COMPLETED · EXCLUSIVE OFFER",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: amberColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Title & Reassurance ─────────────────────────────────────
              Text(
                "Your Premium Trial Has Ended",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You've been switched to the Free plan. Rest assured, all your data and scanned receipts are 100% safe and accessible!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // ── Usage Metrics Summary ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: controller.currentBaseColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              color: accent, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            "${stats.totalReceipts}",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Receipts Saved",
                            style: TextStyle(
                              fontSize: 10.5,
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
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: controller.currentBaseColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.bolt_rounded,
                              color: amberColor, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            "${stats.timeSavedMinutes.toStringAsFixed(1)}m",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Time Saved (AI)",
                            style: TextStyle(
                              fontSize: 10.5,
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

              // ── Urgency Banner & Dual Interactive Plan Cards ────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrangeAccent.withValues(alpha: 0.16),
                      amberColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.deepOrangeAccent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_offer_rounded,
                                size: 15, color: Colors.deepOrangeAccent),
                            const SizedBox(width: 6),
                            Text(
                              "Special 7-Day Discount",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 11, color: Colors.deepOrangeAccent),
                              const SizedBox(width: 3),
                              Text(
                                "7 Days Left",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Interactive Plan Preview Cards
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Annual Preview Card (Dominant)
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.of(context).pop(PaywallPlanType.annual),
                              child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: controller.currentBaseColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accent,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.tealAccent.shade700
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "3 MONTHS FREE",
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.tealAccent.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        "\$3.99",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        "/mo",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Annual · Save 33%",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: accent,
                                    ),
                                  ),
                                  Text(
                                    "Pay for 9 mos, get 12",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Monthly Preview Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pop(PaywallPlanType.monthly),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: controller.currentBaseColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: textSecondary.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: amberColor
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "1 MONTH FREE",
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: amberColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        "\$5.99",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        "/mo",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Monthly Plan",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    "Cancel anytime",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
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
              const SizedBox(height: 18),

              // ── Primary Action CTA ──────────────────────────────────────
              SizedBox(
                height: 50,
                child: NeumorphicButtonWidget(
                  onPressed: () =>
                      Navigator.of(context).pop(PaywallPlanType.annual),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Claim 3 Months Free & Upgrade",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 17),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Secondary Dismiss Action ────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(180, 48),
                  ),
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
                  onPressed: () => Navigator.of(context).pop(true),
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
                  onPressed: () => Navigator.of(context).pop(false),
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

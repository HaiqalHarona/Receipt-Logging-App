import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

import '../../../../constants/subscription_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../../cloud/models/subscription_models.dart';
import '../../../../cloud/services/auth_service.dart';
import '../views/premium_paywall_sheet.dart';

/// Persistent banner displayed on Dashboard/Home screen when user is in
/// the 7-day downgrade discount window.
class DiscountOfferBanner extends StatelessWidget {
  final SubscriptionStatusDto? status;
  final VoidCallback? onOfferClaimed;

  const DiscountOfferBanner({
    super.key,
    this.status,
    this.onOfferClaimed,
  });

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isLoggedIn ||
        status == null ||
        !status!.isDiscountActive ||
        (status!.discountDaysRemaining != null && status!.discountDaysRemaining! <= 0)) {
      return const SizedBox.shrink();
    }

    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final daysRemaining = status!.discountDaysRemaining ?? SubscriptionConstants.downgradeDiscountDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrangeAccent.withValues(alpha: 0.16),
            Colors.amber.shade700.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepOrangeAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final upgraded = await showPremiumPaywallSheet(context);
            if (upgraded == true) {
              onOfferClaimed?.call();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.deepOrangeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Special Discount",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepOrangeAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left",
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Up to 3 months free on subscribing to Premium before this offer ends.",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Claim",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

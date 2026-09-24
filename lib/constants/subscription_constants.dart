/// Subscription & Economic Model Constants
class SubscriptionConstants {
  SubscriptionConstants._();

  // ── RevenueCat Entitlement & Offering IDs ───────────────────────────────────
  static const String premiumEntitlementId = 'sancfund_pro';
  static const String normalOfferingId = 'sancfund_pro_offerings';
  static const String offerOfferingId = 'sancfund_pro_offer_offerings';

  // Standard packages
  static const String monthlyPackageId = r'$rc_monthly';
  static const String annualPackageId = r'$rc_annual';

  // Product identifiers configured in stores
  static const String monthlyProductId = 'monthly';
  static const String annualProductId = 'yearly';

  // Promotional discounted variants (post-trial offer)
  static const String monthlyPromoProductId = 'monthly_offer';
  static const String annualPromoProductId = 'yearly_offer';
  static const String legacyMonthlyProductId = 'premium_monthly';
  static const String legacyAnnualProductId = 'premium_annual';



  // ── Durations & Limits ──────────────────────────────────────────────────────
  static const int reverseTrialDays = 14;
  static const int downgradeDiscountDays = 7;
  static const int maxFreeDailyScans = 5;
  static const int maxDailyAdScans = 5;
  static const int maxTotalFreeScans = 10; // 5 free + 5 ads

  // ── AI Model Time Saved Statistics ──────────────────────────────────────────
  // Average scan time: Free tier = 25.0s, Premium tier = 8.5s
  // Difference = 16.5s saved per scan
  static const double freeScanAvgSeconds = 25.0;
  static const double premiumScanAvgSeconds = 8.5;
  static const double avgTimeSavedPerScanSeconds = freeScanAvgSeconds - premiumScanAvgSeconds; // 16.5s
}

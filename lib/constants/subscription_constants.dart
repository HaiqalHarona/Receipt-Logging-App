/// Subscription & Economic Model Constants
class SubscriptionConstants {
  SubscriptionConstants._();

  // ── RevenueCat Entitlement & Product IDs ───────────────────────────────────
  static const String premiumEntitlementId = 'sancfund_pro';
  static const String defaultOfferingId = 'default';

  // Standard packages
  static const String monthlyPackageId = '\$rc_monthly';
  static const String annualPackageId = '\$rc_annual';

  // Product identifiers configured in stores
  static const String monthlyProductId = 'monthly';
  static const String annualProductId = 'yearly';

  // Legacy & promotional discounted variants
  static const String monthlyPromoProductId = 'premium_monthly_promo';
  static const String annualPromoProductId = 'premium_annual_promo';
  static const String legacyMonthlyProductId = 'premium_monthly';
  static const String legacyAnnualProductId = 'premium_annual';

  // ── Standard Pricing Fallbacks (When store products are loading / sandbox) ──
  static const String monthlyDisplayPrice = '\$5.99';
  static const String annualDisplayPrice = '\$47.88';
  static const String annualMonthlyEquivalent = '\$3.99';

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

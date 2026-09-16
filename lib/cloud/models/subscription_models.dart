// Data models for subscription status, reverse-trial stats, and ad scan rewards.

class UserStatsDto {
  final int totalReceipts;
  final double timeSavedSeconds;
  final double timeSavedMinutes;
  final DateTime? trialStartAt;
  final DateTime? discountOfferShownAt;
  final String tier;
  final bool isInTrial;
  final int adScansToday;
  final int adScansRemaining;

  const UserStatsDto({
    required this.totalReceipts,
    required this.timeSavedSeconds,
    required this.timeSavedMinutes,
    this.trialStartAt,
    this.discountOfferShownAt,
    required this.tier,
    required this.isInTrial,
    required this.adScansToday,
    required this.adScansRemaining,
  });

  factory UserStatsDto.fromJson(Map<String, dynamic> json) {
    return UserStatsDto(
      totalReceipts: json['total_receipts'] as int? ?? 0,
      timeSavedSeconds: (json['time_saved_seconds'] as num?)?.toDouble() ?? 0.0,
      timeSavedMinutes: (json['time_saved_minutes'] as num?)?.toDouble() ?? 0.0,
      trialStartAt: json['trial_start_at'] != null
          ? DateTime.tryParse(json['trial_start_at'].toString())
          : null,
      discountOfferShownAt: json['discount_offer_shown_at'] != null
          ? DateTime.tryParse(json['discount_offer_shown_at'].toString())
          : null,
      tier: (json['tier'] as String? ?? 'free').toLowerCase(),
      isInTrial: json['is_in_trial'] as bool? ?? false,
      adScansToday: json['ad_scans_today'] as int? ?? 0,
      adScansRemaining: json['ad_scans_remaining'] as int? ?? 5,
    );
  }
}

class SubscriptionStatusDto {
  final String tier;
  final bool isInTrial;
  final DateTime? trialStartAt;
  final int? trialDaysRemaining;
  final bool isTrialExpired;
  final DateTime? discountOfferShownAt;
  final int? discountDaysRemaining;
  final bool isDiscountActive;
  final int adScansToday;
  final int adScansRemaining;

  const SubscriptionStatusDto({
    required this.tier,
    required this.isInTrial,
    this.trialStartAt,
    this.trialDaysRemaining,
    required this.isTrialExpired,
    this.discountOfferShownAt,
    this.discountDaysRemaining,
    required this.isDiscountActive,
    required this.adScansToday,
    required this.adScansRemaining,
  });

  factory SubscriptionStatusDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusDto(
      tier: (json['tier'] as String? ?? 'free').toLowerCase(),
      isInTrial: json['is_in_trial'] as bool? ?? false,
      trialStartAt: json['trial_start_at'] != null
          ? DateTime.tryParse(json['trial_start_at'].toString())
          : null,
      trialDaysRemaining: json['trial_days_remaining'] as int?,
      isTrialExpired: json['is_trial_expired'] as bool? ?? false,
      discountOfferShownAt: json['discount_offer_shown_at'] != null
          ? DateTime.tryParse(json['discount_offer_shown_at'].toString())
          : null,
      discountDaysRemaining: json['discount_days_remaining'] as int?,
      isDiscountActive: json['is_discount_active'] as bool? ?? false,
      adScansToday: json['ad_scans_today'] as int? ?? 0,
      adScansRemaining: json['ad_scans_remaining'] as int? ?? 5,
    );
  }
}

class AdScanGrantDto {
  final bool granted;
  final int adScansToday;
  final int adScansRemaining;
  final String message;

  const AdScanGrantDto({
    required this.granted,
    required this.adScansToday,
    required this.adScansRemaining,
    required this.message,
  });

  factory AdScanGrantDto.fromJson(Map<String, dynamic> json) {
    return AdScanGrantDto(
      granted: json['success'] as bool? ?? false,
      adScansToday: json['ad_scans_today'] as int? ?? 0,
      adScansRemaining: json['ad_scans_remaining'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

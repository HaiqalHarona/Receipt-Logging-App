/// Data models representing tier-based daily usage quotas.
///
/// Quota limits for /scan/* and /chat/query reset daily at 00:00 UTC.
/// Tiers supported: 'free' (default & guests), 'premium', 'dev' (unlimited).
library;

class QuotaMetricDto {
  final int used;
  final int limit; // -1 represents unlimited
  final int remaining; // -1 represents unlimited
  final bool isExhausted;

  const QuotaMetricDto({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isExhausted,
  });

  bool get isUnlimited => limit == -1;

  factory QuotaMetricDto.fromJson(Map<String, dynamic> json) {
    return QuotaMetricDto(
      used: (json['used'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      isExhausted: json['is_exhausted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'used': used,
        'limit': limit,
        'remaining': remaining,
        'is_exhausted': isExhausted,
      };
}

class QuotaStatusDto {
  final bool success;
  final String tier;
  final QuotaMetricDto scan;
  final QuotaMetricDto chat;
  final DateTime? resetAt;
  final int secondsToReset;
  final String resetCountdown;

  const QuotaStatusDto({
    this.success = true,
    required this.tier,
    required this.scan,
    required this.chat,
    this.resetAt,
    required this.secondsToReset,
    required this.resetCountdown,
  });

  factory QuotaStatusDto.fromJson(Map<String, dynamic> json) {
    DateTime? parsedResetAt;
    if (json['reset_at'] != null) {
      parsedResetAt = DateTime.tryParse(json['reset_at'] as String);
    }

    return QuotaStatusDto(
      success: json['success'] as bool? ?? true,
      tier: (json['tier'] as String?)?.toLowerCase() ?? 'free',
      scan: json['scan'] is Map<String, dynamic>
          ? QuotaMetricDto.fromJson(json['scan'] as Map<String, dynamic>)
          : const QuotaMetricDto(
              used: 0, limit: 10, remaining: 10, isExhausted: false),
      chat: json['chat'] is Map<String, dynamic>
          ? QuotaMetricDto.fromJson(json['chat'] as Map<String, dynamic>)
          : const QuotaMetricDto(
              used: 0, limit: 10000, remaining: 10000, isExhausted: false),
      resetAt: parsedResetAt,
      secondsToReset: (json['seconds_to_reset'] as num?)?.toInt() ?? 0,
      resetCountdown: (json['reset_countdown'] as String?) ?? '0h 0m',
    );
  }

  String get formattedScanTooltip {
    final limitStr = scan.isUnlimited ? 'Unlimited' : '${scan.limit}';
    return 'Daily scan quota reached (${scan.used}/$limitStr). Resets in $resetCountdown at 00:00 UTC';
  }

  String get formattedChatTooltip {
    final limitStr = chat.isUnlimited
        ? 'Unlimited'
        : (chat.limit >= 1000 ? '${chat.limit ~/ 1000}k' : '${chat.limit}');
    final usedStr =
        chat.used >= 1000 ? '${chat.used ~/ 1000}k' : '${chat.used}';
    return 'Daily chat token quota reached ($usedStr/$limitStr). Resets in $resetCountdown at 00:00 UTC';
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'tier': tier,
        'scan': scan.toJson(),
        'chat': chat.toJson(),
        'reset_at': resetAt?.toIso8601String(),
        'seconds_to_reset': secondsToReset,
        'reset_countdown': resetCountdown,
      };
}

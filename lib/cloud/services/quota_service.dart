import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/quota_models.dart';
import '../api/backend_api_client.dart';
import '../../services/app_logger_service.dart';

/// Central singleton service managing tier-based daily usage quotas (Scan & Chat).
///
/// Automatically tracks daily limits, live 00:00 UTC reset countdown, and provides
/// reactive notifications to update UI disabled states and tooltips.
class QuotaService extends ChangeNotifier {
  QuotaService._();
  static final QuotaService instance = QuotaService._();

  QuotaStatusDto? _status;
  bool _isLoading = false;
  Timer? _countdownTimer;

  QuotaStatusDto? get status => _status;
  bool get isLoading => _isLoading;

  String get tier => _status?.tier.toLowerCase() ?? 'free';

  /// Whether the user has exhausted their daily scan quota.
  bool get isScanQuotaExhausted => _status?.scan.isExhausted ?? false;

  /// Whether the user has exhausted their daily chat token quota.
  bool get isChatQuotaExhausted => _status?.chat.isExhausted ?? false;

  int get scanUsed => _status?.scan.used ?? 0;
  int get scanLimit => _status?.scan.limit ?? 10;
  int get scanRemaining => _status?.scan.remaining ?? 10;
  bool get isScanUnlimited => _status?.scan.isUnlimited ?? false;

  int get chatUsed => _status?.chat.used ?? 0;
  int get chatLimit => _status?.chat.limit ?? 10000;
  int get chatRemaining => _status?.chat.remaining ?? 10000;
  bool get isChatUnlimited => _status?.chat.isUnlimited ?? false;

  /// Live countdown string to next 00:00 UTC reset.
  String get liveResetCountdown {
    if (_status?.resetAt != null) {
      final now = DateTime.now().toUtc();
      final diff = _status!.resetAt!.difference(now);
      if (diff.isNegative) {
        return '0h 0m';
      }
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return '${hours}h ${mins}m';
    }
    return _status?.resetCountdown ?? '0h 0m';
  }

  String get scanTooltip {
    final limitStr = isScanUnlimited ? 'Unlimited' : '$scanLimit';
    return 'Daily scan quota reached ($scanUsed/$limitStr). Resets in $liveResetCountdown at 00:00 UTC';
  }

  String get chatTooltip {
    final limitStr = isChatUnlimited
        ? 'Unlimited'
        : (chatLimit >= 1000 ? '${chatLimit ~/ 1000}k' : '$chatLimit');
    final usedStr = chatUsed >= 1000 ? '${chatUsed ~/ 1000}k' : '$chatUsed';
    return 'Daily chat token quota reached ($usedStr/$limitStr). Resets in $liveResetCountdown at 00:00 UTC';
  }

  /// Initialize service and start periodic countdown tick.
  void init() {
    _startCountdownTimer();
    refreshQuota();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners();
    });
  }

  /// Fetches fresh quota status from backend GET /user/quota.
  Future<void> refreshQuota() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final freshStatus = await BackendApiClient.instance.fetchQuotaStatus();
      if (freshStatus != null) {
        _status = freshStatus;
        notifyListeners();
      }
    } catch (e, st) {
      AppLogger.error('QuotaService', 'Failed to refresh quota status', e, st);
    } finally {
      _isLoading = false;
    }
  }

  /// Optimistically increments local scan usage count after a scan operation.
  void recordLocalScanIncrement(int count) {
    if (_status == null || isScanUnlimited) return;
    final newUsed = _status!.scan.used + count;
    final newRemaining =
        (_status!.scan.limit - newUsed).clamp(0, _status!.scan.limit);
    final isExhausted = newUsed >= _status!.scan.limit;

    _status = QuotaStatusDto(
      success: _status!.success,
      tier: _status!.tier,
      scan: QuotaMetricDto(
        used: newUsed,
        limit: _status!.scan.limit,
        remaining: newRemaining,
        isExhausted: isExhausted,
      ),
      chat: _status!.chat,
      resetAt: _status!.resetAt,
      secondsToReset: _status!.secondsToReset,
      resetCountdown: _status!.resetCountdown,
    );
    notifyListeners();
  }

  /// Optimistically increments local chat token usage count after a chat turn.
  void recordLocalChatTokensIncrement(int tokens) {
    if (_status == null || isChatUnlimited) return;
    final newUsed = _status!.chat.used + tokens;
    final newRemaining =
        (_status!.chat.limit - newUsed).clamp(0, _status!.chat.limit);
    final isExhausted = newUsed >= _status!.chat.limit;

    _status = QuotaStatusDto(
      success: _status!.success,
      tier: _status!.tier,
      scan: _status!.scan,
      chat: QuotaMetricDto(
        used: newUsed,
        limit: _status!.chat.limit,
        remaining: newRemaining,
        isExhausted: isExhausted,
      ),
      resetAt: _status!.resetAt,
      secondsToReset: _status!.secondsToReset,
      resetCountdown: _status!.resetCountdown,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';

import '../../../../constants/subscription_constants.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/subscription_models.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/quota_service.dart';
import '../views/premium_paywall_sheet.dart';

/// Shows an ad reward modal or prompt when daily scans are exhausted.
Future<void> showAdScanPromptDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (ctx) => const AdScanPromptDialog(),
  );
}

/// Modal dialog prompting the user to either watch a rewarded ad (+1 scan)
/// or upgrade to Premium when quota is exhausted.
class AdScanPromptDialog extends StatefulWidget {
  const AdScanPromptDialog({super.key});

  @override
  State<AdScanPromptDialog> createState() => _AdScanPromptDialogState();
}

class _AdScanPromptDialogState extends State<AdScanPromptDialog> {
  UserStatsDto? _stats;
  bool _isWatchingAd = false;
  int _countdown = 3;
  Timer? _adTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (!AuthService.instance.isLoggedIn) {
      return;
    }
    try {
      final stats = await BackendApiClient.instance.getUserStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      AppLogger.warning('AdScan', 'Failed to load stats for ad scan prompt: $e');
    }
  }

  void _startRewardedAdSimulation() {
    setState(() {
      _isWatchingAd = true;
      _countdown = 3;
    });

    _adTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        if (mounted) {
          setState(() => _countdown--);
        }
      } else {
        timer.cancel();
        await _claimAdReward();
      }
    });
  }

  Future<void> _claimAdReward() async {
    try {
      final res = await BackendApiClient.instance.grantAdScan();
      if (res.granted) {
        await QuotaService.instance.refreshQuota();
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackBar.show(
            context,
            message: '🎉 +1 Scan Granted! You can now scan a receipt.',
          );
        }
      } else {
        if (mounted) {
          setState(() => _isWatchingAd = false);
          AppSnackBar.show(
            context,
            message: res.message.isNotEmpty
                ? res.message
                : 'Could not grant ad scan at this time.',
            isError: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('AdScan', 'Error claiming ad scan reward: $e');
      if (mounted) {
        setState(() => _isWatchingAd = false);
        AppSnackBar.show(
          context,
          message: 'Failed to claim ad scan reward.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final amberColor = Colors.amber.shade600;

    final adScansToday = _stats?.adScansToday ?? 0;
    final canWatchAd = adScansToday < SubscriptionConstants.maxDailyAdScans;
    final isLoggedIn = AuthService.instance.isLoggedIn;

    if (!isLoggedIn) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                      color: Colors.deepOrangeAccent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: Colors.deepOrangeAccent,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Daily Scan Limit Reached",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Guest mode includes 5 scans per day. Sign in or register to unlock bonus ad scans, cloud sync, and unlimited premium plans.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: NeumorphicButtonWidget(
                    color: accent,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/auth');
                    },
                    child: const Center(
                      child: Text(
                        "Sign In / Register",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
                      "Maybe Later",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isWatchingAd) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 0,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
            color: NeumorphicTheme.baseColor(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.movie_creation_rounded,
                    color: accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Sponsored Ad",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Simulating rewarded 30-second ad...\nReward in $_countdown seconds",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                    color: Colors.deepOrangeAccent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: Colors.deepOrangeAccent,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Daily Scan Limit Reached",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Free plan includes 5 scans per day. Your quota resets at 00:00 UTC (in ${QuotaService.instance.liveResetCountdown}).",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // ── Option A: Rewarded Ad (+1 scan) ──────────────────────────
              if (canWatchAd) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.currentBaseColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: accent, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Watch 30s Ad for +1 Scan",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$adScansToday/5 bonus scans used today",
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: NeumorphicButtonWidget(
                    onPressed: _startRewardedAdSimulation,
                    child: const Center(
                      child: Text(
                        "Watch Ad for +1 Scan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "Daily ad scan limit reached (5/5 used).",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Option B: Upgrade to Premium ─────────────────────────────
              SizedBox(
                height: 46,
                child: NeumorphicButtonWidget(
                  color: amberColor,
                  onPressed: () {
                    Navigator.of(context).pop();
                    showPremiumPaywallSheet(context);
                  },
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Upgrade to Premium (50/day)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: textSecondary, fontSize: 13),
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

/// Compact inline banner for the Scanner screen shown when scan quota is exhausted.
class ScannerQuotaExhaustedBanner extends StatefulWidget {
  final VoidCallback? onRewardClaimed;

  const ScannerQuotaExhaustedBanner({super.key, this.onRewardClaimed});

  @override
  State<ScannerQuotaExhaustedBanner> createState() =>
      _ScannerQuotaExhaustedBannerState();
}

class _ScannerQuotaExhaustedBannerState
    extends State<ScannerQuotaExhaustedBanner> {
  UserStatsDto? _stats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final stats = await BackendApiClient.instance.getUserStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!QuotaService.instance.isScanQuotaExhausted) {
      return const SizedBox.shrink();
    }

    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final amberColor = Colors.amber.shade600;

    final adScansToday = _stats?.adScansToday ?? 0;
    final canWatchAd = adScansToday < SubscriptionConstants.maxDailyAdScans;
    final isLoggedIn = AuthService.instance.isLoggedIn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepOrangeAccent.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepOrangeAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded,
              color: Colors.deepOrangeAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Daily Scan Limit Reached (5/5)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  !isLoggedIn
                      ? "Sign in to unlock more scans & sync"
                      : (canWatchAd
                          ? "Watch 30s ad for +1 scan ($adScansToday/5 used)"
                          : "Daily ad scans exhausted. Resets at 00:00 UTC"),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isLoggedIn)
            GestureDetector(
              onTap: () => context.push('/auth'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded,
                        color: Colors.white, size: 14),
                    SizedBox(width: 3),
                    Text(
                      "Sign In",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (canWatchAd)
            GestureDetector(
              onTap: () async {
                await showAdScanPromptDialog(context);
                await _fetchStats();
                widget.onRewardClaimed?.call();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 14),
                    SizedBox(width: 2),
                    Text(
                      "+1 Scan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => showPremiumPaywallSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: amberColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Upgrade",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

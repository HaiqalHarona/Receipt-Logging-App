import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../constants/subscription_constants.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/account_required_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../cloud/api/backend_api_client.dart';
import '../../../../cloud/models/subscription_models.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../cloud/services/quota_service.dart';
import '../../../../cloud/services/subscription_service.dart';

/// Shows the refined RevenueCat-powered Premium Paywall modal bottom sheet.
Future<bool?> showPremiumPaywallSheet(
  BuildContext context, {
  PaywallPlanType initialPlan = PaywallPlanType.annual,
}) {
  if (!AuthService.instance.isLoggedIn) {
    AccountRequiredDialog.show(
      context,
      title: 'Sign In for Premium',
      message:
          'A registered account is required to subscribe to Premium and sync your subscription across devices.',
    );
    return Future.value(false);
  }

  final screenHeight = MediaQuery.of(context).size.height;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: screenHeight * (5 / 6),
      child: PremiumPaywallSheet(initialPlan: initialPlan),
    ),
  );
}

enum PaywallPlanType { annual, monthly }

class PremiumPaywallSheet extends StatefulWidget {
  final bool isFullPage;
  final PaywallPlanType initialPlan;

  const PremiumPaywallSheet({
    super.key,
    this.isFullPage = false,
    this.initialPlan = PaywallPlanType.annual,
  });

  @override
  State<PremiumPaywallSheet> createState() => _PremiumPaywallSheetState();
}

class _PremiumPaywallSheetState extends State<PremiumPaywallSheet> {
  late PaywallPlanType _selectedPlan;
  Offerings? _offerings;
  SubscriptionStatusDto? _subStatus;
  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  int _offeringsRetryCount = 0;
  static const int _maxOfferingsRetries = 3;
  static const Duration _offeringsRetryDelay = Duration(seconds: 5);

  Timer? _offeringsRetryTimer;

  /// True only when RC has successfully delivered both packages.
  bool get _isProductsReady =>
      !_isLoadingOfferings &&
      _annualPackage != null &&
      _monthlyPackage != null;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
    _isLoadingOfferings = true;
    _loadOfferingsAndStatus();
  }

  @override
  void dispose() {
    _offeringsRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOfferingsAndStatus() async {
    try {
      final offerings = await SubscriptionService.instance.getOfferings();
      SubscriptionStatusDto? status;
      if (AuthService.instance.isLoggedIn) {
        try {
          status = await BackendApiClient.instance.getSubscriptionStatus();
        } catch (e) {
          AppLogger.warning('Paywall', 'Failed to fetch subscription status: $e');
        }
      }

      if (mounted) {
        setState(() {
          _offerings = offerings;
          _subStatus = status;
          _isLoadingOfferings = false;
        });
      }
      _scheduleOfferingsRetryIfNeeded();
      AppLogger.info(
        'Paywall',
        'Offerings loaded: current=${offerings?.current?.identifier}, '
        'allOfferings=${offerings?.all.keys.toList()}, '
        'availableCount=${_currentOffering?.availablePackages.length ?? 0}',
      );
    } catch (e, st) {
      AppLogger.warning('Paywall', 'Error loading offerings/status: $e', st);
      if (mounted) {
        setState(() => _isLoadingOfferings = false);
      }
      _scheduleOfferingsRetryIfNeeded();
    }
  }

  void _scheduleOfferingsRetryIfNeeded() {
    if (_isProductsReady || _offeringsRetryCount >= _maxOfferingsRetries) return;

    _offeringsRetryTimer?.cancel();
    _offeringsRetryTimer = Timer(_offeringsRetryDelay, () async {
      if (!mounted || _isProductsReady) return;
      _offeringsRetryCount++;
      try {
        final offerings = await SubscriptionService.instance.getOfferings();
        if (mounted) {
          setState(() {
            _offerings = offerings;
          });
        }
      } catch (_) {}
      if (mounted) {
        _scheduleOfferingsRetryIfNeeded();
      }
    });
  }

  Offering? get _currentOffering {
    if (_offerings == null) return null;
    final targetOfferingId = _isDiscountActive
        ? SubscriptionConstants.offerOfferingId
        : SubscriptionConstants.normalOfferingId;
    return _offerings!.all[targetOfferingId] ??
        _offerings!.current ??
        (_offerings!.all.isNotEmpty ? _offerings!.all.values.first : null);
  }

  Package? get _annualPackage {
    final available = _currentOffering?.availablePackages;
    if (available == null || available.isEmpty) return null;
    try {
      return available.firstWhere(
        (p) =>
            p.packageType == PackageType.annual ||
            p.identifier == SubscriptionConstants.annualPackageId ||
            p.identifier == SubscriptionConstants.annualPromoProductId ||
            p.storeProduct.identifier == SubscriptionConstants.annualProductId ||
            p.storeProduct.identifier == SubscriptionConstants.annualPromoProductId ||
            p.storeProduct.identifier == SubscriptionConstants.legacyAnnualProductId ||
            p.identifier.toLowerCase().contains('annual') ||
            p.identifier.toLowerCase().contains('year') ||
            p.storeProduct.identifier.toLowerCase().contains('annual') ||
            p.storeProduct.identifier.toLowerCase().contains('year'),
      );
    } catch (_) {
      return available.first;
    }
  }

  Package? get _monthlyPackage {
    final available = _currentOffering?.availablePackages;
    if (available == null || available.isEmpty) return null;
    try {
      return available.firstWhere(
        (p) =>
            p.packageType == PackageType.monthly ||
            p.identifier == SubscriptionConstants.monthlyPackageId ||
            p.identifier == SubscriptionConstants.monthlyPromoProductId ||
            p.storeProduct.identifier == SubscriptionConstants.monthlyProductId ||
            p.storeProduct.identifier == SubscriptionConstants.monthlyPromoProductId ||
            p.storeProduct.identifier == SubscriptionConstants.legacyMonthlyProductId ||
            p.identifier.toLowerCase().contains('month') ||
            p.storeProduct.identifier.toLowerCase().contains('month'),
      );
    } catch (_) {
      return available.length > 1 ? available[1] : available.first;
    }
  }

  Package? get _currentSelectedPackage {
    return _selectedPlan == PaywallPlanType.annual
        ? _annualPackage
        : _monthlyPackage;
  }

  /// USD Display string for Annual monthly-equivalent price.
  String get _annualPriceMainDisplay {
    if (!_isProductsReady) return '—';
    return _isDiscountActive ? r'$1.50*' : r'$2.00*';
  }

  /// USD Display string for Monthly price.
  String get _monthlyPriceMainDisplay {
    if (!_isProductsReady) return '—';
    return _isDiscountActive ? r'$1.99*' : r'$2.99*';
  }

  /// Strikethrough price for Annual card.
  String? get _annualStrikeThroughPrice {
    if (!_isProductsReady) return null;
    return _isDiscountActive ? r'$2.00' : r'$2.99';
  }

  /// Strikethrough price for Monthly card (shown only during discount mode).
  String? get _monthlyStrikeThroughPrice {
    if (!_isProductsReady) return null;
    return _isDiscountActive ? r'$2.99' : null;
  }

  /// Billing period subtext for Annual card.
  String get _annualBillingPeriodText {
    if (!_isProductsReady) return "Billed annually";
    return _isDiscountActive
        ? "Billed \$17.99 for 1st year"
        : "Billed \$23.99 / year";
  }

  /// Calculated annual discount percentage relative to monthly billing term.
  /// Example: ((2.99 - (23.99 / 12)) / 2.99 * 100) = 33%
  int? get _savePercent {
    if (!_isProductsReady) return null;
    return 33;
  }

  /// Badge text for the Annual plan card.
  String get _annualBadgeText {
    if (_isDiscountActive) return "3 MONTHS FREE";
    return _isProductsReady ? "SAVE 33%" : "BEST VALUE";
  }

  /// Subtext note for the Annual plan card.
  String get _annualPromoNote {
    if (_isDiscountActive) return "Pay for 9 mos, get 12 · 90 days on us ;)";
    return _isProductsReady ? "Best Value · Save 33%" : "Best value overall";
  }

  /// Subtext note for the Monthly plan card.
  String get _monthlyPromoNote {
    if (!_isDiscountActive) return "Flexible · Cancel anytime";
    return "First month \$1.99, then \$2.99/mo";
  }

  bool get _isDiscountActive {
    final status = _subStatus;
    if (status == null) return false;
    if (status.trialStartAt == null) return false;
    if (status.tier == 'premium') return false;
    return status.isDiscountActive;
  }

  int get _discountDaysRemaining {
    return _subStatus?.discountDaysRemaining ?? SubscriptionConstants.downgradeDiscountDays;
  }

  Future<void> _onPurchase() async {
    if (_isPurchasing) return;
    AppLogger.info('Paywall', 'User tapped purchase for plan: $_selectedPlan');

    if (_isLoadingOfferings) {
      AppLogger.info('Paywall', 'Offerings still loading, waiting...');
      AppSnackBar.show(
        context,
        message: 'Connecting to store, please wait a moment...',
      );
      return;
    }

    final package = _currentSelectedPackage;
    if (package == null) {
      final isConfigured = SubscriptionService.instance.isConfigured;
      AppLogger.warning(
        'Paywall',
        'Cannot initiate purchase: package is null for $_selectedPlan. '
        'isConfigured=$isConfigured, '
        'offeringsLoaded=${_offerings != null}, '
        'currentOffering=${_currentOffering?.identifier}, '
        'availablePackages=${_currentOffering?.availablePackages.map((p) => "${p.identifier} (${p.storeProduct.identifier})").toList()}',
      );

      if (!isConfigured) {
        AppSnackBar.show(
          context,
          message:
              'In-app purchases are not configured or supported on this device.',
          isError: true,
        );
      } else {
        AppSnackBar.show(
          context,
          message:
              'Store products unavailable. Please ensure in-app purchases are configured and try again.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _isPurchasing = true);
    AppLogger.info('Paywall',
        'User tapped purchase for plan: $_selectedPlan (package: ${package.identifier})');

    try {
      final success =
          await SubscriptionService.instance.purchasePackage(package);
      if (success) {
        await _onPurchaseSuccess();
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        AppLogger.info('Paywall', 'Purchase cancelled by user');
      } else {
        AppLogger.error('Paywall', 'Purchase platform exception: ${e.message}');
        if (mounted) {
          AppSnackBar.show(
            context,
            message: e.message ?? 'Purchase could not be completed.',
            isError: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Paywall', 'Unexpected purchase error: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'An unexpected error occurred during purchase.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _onPurchaseSuccess() async {
    if (!mounted) return;
    setState(() {
      if (_subStatus != null) {
        _subStatus = _subStatus!.copyWith(
          isDiscountActive: false,
          tier: 'premium',
          discountDaysRemaining: 0,
        );
      }
    });
    AppSnackBar.show(
      context,
      message: '🎉 Welcome to Premium! All features unlocked.',
    );
    await AuthService.instance.getOrFetchProfile(force: true);
    await QuotaService.instance.refreshQuota();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onRestore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    AppLogger.info('Paywall', 'User tapped Restore Purchases');

    try {
      final success = await SubscriptionService.instance.restorePurchases();
      if (success) {
        await _onPurchaseSuccess();
      } else {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'No active Premium subscription found to restore.',
          );
        }
      }
    } catch (e) {
      AppLogger.error('Paywall', 'Restore purchases failed: $e');
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Unable to restore purchases at this time.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
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

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: widget.isFullPage ? 8 : 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for bottom sheet mode
          if (!widget.isFullPage)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amberColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: amberColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: amberColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Premium",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: amberColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "PRO",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: amberColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Supercharge your receipt workflow with flagship AI.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isFullPage)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                  splashRadius: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 7-Day Downgrade Discount Urgency Banner ─────────────────────
          if (_isDiscountActive)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepOrangeAccent.withValues(alpha: 0.2),
                    amberColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.deepOrangeAccent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrangeAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.deepOrangeAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Special 7-Day Discount",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Get up to 3 months free. Offer expires in $_discountDaysRemaining days!",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Plan Selector Cards ──────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Annual Plan Option (Dominant & Pre-selected)
                Expanded(
                  child: _buildPlanOptionCard(
                    isEnabled: _isProductsReady,
                    plan: PaywallPlanType.annual,
                    title: "Annual",
                    badge: _annualBadgeText,
                    badgeColor: Colors.tealAccent.shade700,
                    isRecommended: true,
                    strikeThroughPrice: _annualStrikeThroughPrice,
                    priceMain: _annualPriceMainDisplay,
                    priceSub: "/mo",
                    billingPeriod: _annualBillingPeriodText,
                    promoNote: _annualPromoNote,
                    isSelected: _selectedPlan == PaywallPlanType.annual,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    controller: controller,
                  ),
                ),
                const SizedBox(width: 10),
                // Monthly Plan Option
                Expanded(
                  child: _buildPlanOptionCard(
                    isEnabled: _isProductsReady,
                    plan: PaywallPlanType.monthly,
                    title: "Monthly",
                    badge: _isDiscountActive ? "FIRST MONTH OFF" : "FLEXIBLE",
                    badgeColor: amberColor,
                    isRecommended: false,
                    strikeThroughPrice: _monthlyStrikeThroughPrice,
                    priceMain: _monthlyPriceMainDisplay,
                    priceSub: "/mo",
                    billingPeriod: "Billed monthly",
                    promoNote: _monthlyPromoNote,
                    isSelected: _selectedPlan == PaywallPlanType.monthly,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    controller: controller,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _isDiscountActive
                ? "* Prices shown in USD. One-time offer."
                : "* Prices shown in USD.",
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Premium Features List ───────────────────────────────────────
          NeumorphicCardWidget(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WHAT'S INCLUDED",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  icon: Icons.camera_alt_rounded,
                  iconColor: accent,
                  title: "50 Daily Receipt Scans",
                  subtitle: "10x higher allowance vs Free (5/day)",
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const Divider(height: 20, thickness: 0.6),
                _buildBenefitItem(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Colors.tealAccent.shade400,
                  title: "50,000 AI Chat Tokens",
                  subtitle: "Gain customized and useful spending insights",
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const Divider(height: 20, thickness: 0.6),
                _buildBenefitItem(
                  icon: Icons.flash_on_rounded,
                  iconColor: amberColor,
                  title: "Priority Vision OCR Processing",
                  subtitle: "Save ~16.5s per scan with flagship AI",
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const Divider(height: 20, thickness: 0.6),
                _buildBenefitItem(
                  icon: Icons.cloud_sync_rounded,
                  iconColor: Colors.deepPurpleAccent.shade200,
                  title: "Instant Multi-Device Cloud Sync",
                  subtitle: "Automatic backup to your cloud vault",
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Primary Action CTA ──────────────────────────────────────────
          SizedBox(
            height: 52,
            child: NeumorphicButtonWidget(
              onPressed: (_isPurchasing || !_isProductsReady) ? null : _onPurchase,
              child: Center(
                child: _isPurchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            !_isProductsReady
                                ? "Loading prices…"
                                : (_isDiscountActive
                                    ? (_selectedPlan == PaywallPlanType.annual
                                        ? "Claim 3 Months Free & Upgrade"
                                        : "Claim Offer & Upgrade")
                                    : (_selectedPlan == PaywallPlanType.annual
                                        ? (_savePercent != null
                                            ? "Upgrade to Annual (Save $_savePercent%)"
                                            : "Upgrade to Annual Plan")
                                        : "Upgrade to Monthly")),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_isProductsReady) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Restore Purchases & Cancel Info ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isRestoring ? null : _onRestore,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _isRestoring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          "Restore Purchases",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            decoration: TextDecoration.underline,
                            decorationColor: textSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Legal & Store Notice ────────────────────────────────────────
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Subscriptions auto-renew unless cancelled at least 24 hours prior. ",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondary.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                GestureDetector(
                  onTap: () => context.push('/legal/terms'),
                  child: Text(
                    "Terms of Service",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  " • ",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/legal/privacy'),
                  child: Text(
                    "Privacy Policy",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isFullPage) {
      return NeumorphicBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              "Upgrade Plan",
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SafeArea(child: content),
        ),
      );
    }

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: NeumorphicTheme.baseColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildPlanOptionCard({
    required PaywallPlanType plan,
    required String title,
    required String badge,
    required Color badgeColor,
    required bool isRecommended,
    required String? strikeThroughPrice,
    required String priceMain,
    required String priceSub,
    required String billingPeriod,
    required String promoNote,
    required bool isSelected,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required AppThemeController controller,
    bool isEnabled = true,
  }) {
    final card = GestureDetector(
      onTap: isEnabled ? () => setState(() => _selectedPlan = plan) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : controller.currentBaseColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : textSecondary.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRecommended)
              Container(
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : textSecondary.withValues(alpha: 0.18),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "MOST POPULAR · BEST VALUE",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
              )
            else
              const SizedBox(height: 22),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isSelected ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : textSecondary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        priceMain,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        priceSub,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      if (strikeThroughPrice != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          strikeThroughPrice,
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary.withValues(alpha: 0.6),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billingPeriod,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    promoNote,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? accent
                          : textSecondary.withValues(alpha: 0.8),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

    if (!isEnabled) {
      return IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: 0.5,
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

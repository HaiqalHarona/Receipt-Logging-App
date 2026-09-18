import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../constants/subscription_constants.dart';
import '../../services/app_logger_service.dart' hide LogLevel;
import '../api/backend_api_client.dart';
import 'auth_service.dart';

/// Service managing RevenueCat SDK initialization, offering retrieval,
/// in-app purchases, entitlement tracking, and backend synchronization.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _isConfigured = false;
  Offerings? _cachedOfferings;

  bool get isConfigured => _isConfigured;
  Offerings? get cachedOfferings => _cachedOfferings;

  /// Configure RevenueCat Purchases SDK using REVENUE_CAT_KEY from .env
  Future<void> initialize([String? appUserId]) async {
    if (kIsWeb) {
      AppLogger.info('Subscription', 'Purchases SDK skipped on Web platform');
      return;
    }

    if (_isConfigured) {
      if (appUserId != null) {
        await logIn(appUserId);
      }
      return;
    }

    const envKey = String.fromEnvironment('REVENUE_CAT_KEY');
    final apiKey = envKey.isNotEmpty
        ? envKey
        : (dotenv.isInitialized ? dotenv.maybeGet('REVENUE_CAT_KEY') : null);
    if (apiKey == null || apiKey.isEmpty) {
      AppLogger.warning(
        'Subscription',
        'REVENUE_CAT_KEY not found in environment or .env — RevenueCat will run in mockup/unconfigured mode',
      );
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final userId = appUserId ?? AuthService.instance.currentUserId;
      final configuration = PurchasesConfiguration(apiKey);
      if (userId != null && userId.isNotEmpty) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);
      _isConfigured = true;
      AppLogger.info(
        'Subscription',
        'RevenueCat Purchases SDK configured successfully (appUserID: ${configuration.appUserID ?? "anonymous"})',
      );

      // Pre-warm offerings cache
      await getOfferings();
    } catch (e, st) {
      AppLogger.warning('Subscription', 'Failed to configure RevenueCat: $e', st);
    }
  }

  /// Associate backend user ID with RevenueCat on login or registration
  Future<void> logIn(String userId) async {
    if (!_isConfigured || kIsWeb) return;
    try {
      final logInResult = await Purchases.logIn(userId);
      AppLogger.info(
        'Subscription',
        'RevenueCat logged in user: $userId (created: ${logInResult.created})',
      );
      await checkAndSyncEntitlements();
    } catch (e) {
      AppLogger.warning('Subscription', 'RevenueCat logIn error for $userId: $e');
    }
  }

  /// Reset to anonymous user on logout
  Future<void> logOut() async {
    _cachedOfferings = null;
    if (!_isConfigured || kIsWeb) return;
    try {
      await Purchases.logOut();
      AppLogger.info('Subscription', 'RevenueCat logged out');
    } catch (e) {
      AppLogger.warning('Subscription', 'RevenueCat logOut error: $e');
    }
  }

  /// Retrieve current offerings from RevenueCat with fallback to cached
  Future<Offerings?> getOfferings({bool forceRefresh = false}) async {
    if (!_isConfigured || kIsWeb) {
      AppLogger.info('Subscription', 'getOfferings skipped (isConfigured=$_isConfigured, kIsWeb=$kIsWeb)');
      return null;
    }

    if (!forceRefresh && _cachedOfferings != null) {
      return _cachedOfferings;
    }

    try {
      final offerings = await Purchases.getOfferings();
      _cachedOfferings = offerings;
      AppLogger.info(
        'Subscription',
        'Fetched offerings: current=${offerings.current?.identifier}, '
        'availablePackages=${offerings.current?.availablePackages.length ?? 0}, '
        'allOfferings=${offerings.all.keys.toList()}',
      );
      return offerings;
    } catch (e) {
      AppLogger.warning('Subscription', 'Failed to fetch offerings from RevenueCat: $e');
      return _cachedOfferings;
    }
  }

  /// Purchase a selected package (e.g. monthly or annual subscription)
  Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured || kIsWeb) {
      throw PlatformException(
        code: 'NOT_CONFIGURED',
        message: 'RevenueCat is not configured on this device.',
      );
    }

    try {
      AppLogger.info('Subscription', 'Initiating purchase for package: ${package.identifier}');
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = purchaseResult.customerInfo;

      AppLogger.info(
        'Subscription',
        'RevenueCat Purchase result: package=${package.identifier}, '
        'entitlements=${customerInfo.entitlements.all.map((k, v) => MapEntry(k, v.isActive))}, '
        'activeSubscriptions=${customerInfo.activeSubscriptions.toList()}, '
        'allExpirationDates=${customerInfo.allExpirationDates}',
      );

      final isPremium = _evaluatePremiumEntitlement(customerInfo);
      final activeEntitlement = customerInfo.entitlements.all[SubscriptionConstants.premiumEntitlementId];
      final expirationDateStr = activeEntitlement?.expirationDate;

      // Sync entitlement state with FastAPI backend
      await syncWithBackend(
        isPremium: isPremium,
        productIdentifier: package.storeProduct.identifier,
        originalPurchaseDate: customerInfo.originalPurchaseDate,
        expirationDate: expirationDateStr,
      );

      return isPremium;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        AppLogger.info('Subscription', 'User cancelled purchase');
        return false;
      }
      AppLogger.error('Subscription', 'Purchase failed with error code $errorCode: ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('Subscription', 'Unexpected purchase error: $e');
      rethrow;
    }
  }

  /// Restore previous purchases (e.g. after reinstalling or switching device)
  Future<bool> restorePurchases() async {
    if (!_isConfigured || kIsWeb) return false;

    try {
      AppLogger.info('Subscription', 'Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      final isPremium = _evaluatePremiumEntitlement(customerInfo);
      final activeEntitlement = customerInfo.entitlements.all[SubscriptionConstants.premiumEntitlementId];
      final expirationDateStr = activeEntitlement?.expirationDate;

      await syncWithBackend(
        isPremium: isPremium,
        originalPurchaseDate: customerInfo.originalPurchaseDate,
        expirationDate: expirationDateStr,
      );

      return isPremium;
    } catch (e) {
      AppLogger.warning('Subscription', 'Restore purchases failed: $e');
      rethrow;
    }
  }

  /// Check active entitlement on device and sync with backend
  Future<bool> checkAndSyncEntitlements() async {
    if (!_isConfigured || kIsWeb) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = _evaluatePremiumEntitlement(customerInfo);
      final activeEntitlement = customerInfo.entitlements.all[SubscriptionConstants.premiumEntitlementId];
      final expirationDateStr = activeEntitlement?.expirationDate;

      await syncWithBackend(
        isPremium: isPremium,
        originalPurchaseDate: customerInfo.originalPurchaseDate,
        expirationDate: expirationDateStr,
      );

      return isPremium;
    } catch (e) {
      AppLogger.warning('Subscription', 'Check entitlements error: $e');
      return false;
    }
  }

  /// Check if user has active premium entitlement in CustomerInfo.
  /// Falls back to checking any active entitlement, then activeSubscriptions.
  bool _evaluatePremiumEntitlement(CustomerInfo info) {
    // 1. Primary: check the configured entitlement ID ('sancfund_pro')
    final entitlement = info.entitlements.all[SubscriptionConstants.premiumEntitlementId];
    if (entitlement != null && entitlement.isActive) {
      return true;
    }

    // 2. Fallback: check if any entitlement is active
    final anyEntitlementActive = info.entitlements.all.values.any((e) => e.isActive);
    if (anyEntitlementActive) {
      final activeKeys = info.entitlements.all.entries
          .where((e) => e.value.isActive)
          .map((e) => e.key)
          .toList();
      AppLogger.info(
        'Subscription',
        'Configured entitlement "${SubscriptionConstants.premiumEntitlementId}" not active, '
        'but found other active entitlements: $activeKeys. Treating as premium.',
      );
      return true;
    }

    // 3. Fallback: active subscriptions exist (reliable in sandbox/test environments)
    if (info.activeSubscriptions.isNotEmpty) {
      AppLogger.info(
        'Subscription',
        'No active entitlement found, but active subscriptions exist: ${info.activeSubscriptions.toList()}. '
        'Treating as premium.',
      );
      return true;
    }

    return false;
  }

  /// Push updated entitlement status to FastAPI backend (/subscriptions/sync)
  Future<void> syncWithBackend({
    required bool isPremium,
    String? productIdentifier,
    String? originalPurchaseDate,
    String? expirationDate,
  }) async {
    try {
      if (!AuthService.instance.isLoggedIn) return;

      await BackendApiClient.instance.syncSubscription(
        isPremium: isPremium,
        productIdentifier: productIdentifier,
        originalPurchaseDate: originalPurchaseDate,
        expirationDate: expirationDate,
      );
      AppLogger.info('Subscription', 'Backend subscription synced: isPremium=$isPremium');
    } catch (e) {
      AppLogger.warning('Subscription', 'Failed to sync subscription with backend: $e');
    }
  }
}

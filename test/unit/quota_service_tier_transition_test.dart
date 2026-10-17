// test/unit/quota_service_tier_transition_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/models/receipt_models.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/services/cloud_sync_service.dart';

class MockTierTransitionBackendApiClient extends BackendApiClient {
  QuotaStatusDto? mockQuotaStatus;
  int fetchQuotaStatusCallCount = 0;

  List<({String? username, int? limit, int? offset})> fetchReceiptsCalls = [];
  Future<List<ReceiptRecordDto>> Function(String? username, int? limit, int? offset)? onFetchReceipts;

  @override
  Future<QuotaStatusDto?> fetchQuotaStatus({String? username, String? userToken}) async {
    fetchQuotaStatusCallCount++;
    return mockQuotaStatus;
  }

  @override
  Future<List<ReceiptRecordDto>> fetchReceipts({
    String? username,
    String? userToken,
    int? limit,
    int? offset,
    String? updatedAfter,
  }) async {
    fetchReceiptsCalls.add((username: username, limit: limit, offset: offset));
    if (onFetchReceipts != null) {
      return onFetchReceipts!(username, limit, offset);
    }
    return [];
  }
}

QuotaStatusDto _buildStatus(String tier) {
  return QuotaStatusDto(
    success: true,
    tier: tier,
    scan: const QuotaMetricDto(
      used: 0,
      limit: 10,
      remaining: 10,
      isExhausted: false,
    ),
    chat: const QuotaMetricDto(
      used: 0,
      limit: 10000,
      remaining: 10000,
      isExhausted: false,
    ),
    resetAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
    secondsToReset: 43200,
    resetCountdown: '12h 0m',
  );
}

ReceiptRecordDto _buildReceiptRecord(String id, int lineItemCount) {
  return ReceiptRecordDto(
    id: id,
    deviceId: 'test_device_1',
    createdAt: DateTime.now().toUtc().toIso8601String(),
    receipt: ReceiptDto(
      merchantName: 'Merchant $id',
      totalAmount: 49.99,
      date: '2026-10-17',
      rawText: 'Receipt raw text $id',
      lineItems: List.generate(
        lineItemCount,
        (i) => LineItemDto(
          description: 'Item $i for $id',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiClient originalClient;
  late MockTierTransitionBackendApiClient mockClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalClient = BackendApiClient.instance;
    mockClient = MockTierTransitionBackendApiClient();
    BackendApiClient.instance = mockClient;

    await AuthService.instance.clearSession();
    await ReceiptRepository.instance.clearAll();
    QuotaService.instance.setStatusForTesting(null);
    QuotaService.instance.lastKnownTier = null;
    QuotaService.instance.onTierUpgradedToPremium = null;
    CloudSyncService.instance.isReSyncingForPremium = false;
  });

  tearDown(() async {
    await AuthService.instance.clearSession();
    await ReceiptRepository.instance.clearAll();
    QuotaService.instance.setStatusForTesting(null);
    QuotaService.instance.lastKnownTier = null;
    QuotaService.instance.onTierUpgradedToPremium = null;
    CloudSyncService.instance.isReSyncingForPremium = false;
    BackendApiClient.instance = originalClient;
  });

  group('QuotaService Tier Transition Observer', () {
    test('fires onTierUpgradedToPremium when transitioning from free to premium', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('free'));
      expect(QuotaService.instance.tier, equals('free'));
      expect(QuotaService.instance.lastKnownTier, equals('free'));

      int upgradeCallbackCount = 0;
      QuotaService.instance.onTierUpgradedToPremium = () {
        upgradeCallbackCount++;
      };

      mockClient.mockQuotaStatus = _buildStatus('premium');
      await QuotaService.instance.refreshQuota();

      expect(upgradeCallbackCount, equals(1));
      expect(QuotaService.instance.tier, equals('premium'));
      expect(QuotaService.instance.lastKnownTier, equals('premium'));
    });

    test('fires onTierUpgradedToPremium when transitioning from free to dev', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('free'));

      int upgradeCallbackCount = 0;
      QuotaService.instance.onTierUpgradedToPremium = () {
        upgradeCallbackCount++;
      };

      mockClient.mockQuotaStatus = _buildStatus('dev');
      await QuotaService.instance.refreshQuota();

      expect(upgradeCallbackCount, equals(1));
      expect(QuotaService.instance.tier, equals('dev'));
      expect(QuotaService.instance.lastKnownTier, equals('dev'));
    });

    test('does not fire when refreshing while staying on free tier', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('free'));

      int upgradeCallbackCount = 0;
      QuotaService.instance.onTierUpgradedToPremium = () {
        upgradeCallbackCount++;
      };

      mockClient.mockQuotaStatus = _buildStatus('free');
      await QuotaService.instance.refreshQuota();

      expect(upgradeCallbackCount, equals(0));
      expect(QuotaService.instance.tier, equals('free'));
    });

    test('does not fire when already premium and refreshing with premium', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('premium'));
      expect(QuotaService.instance.lastKnownTier, equals('premium'));

      int upgradeCallbackCount = 0;
      QuotaService.instance.onTierUpgradedToPremium = () {
        upgradeCallbackCount++;
      };

      mockClient.mockQuotaStatus = _buildStatus('premium');
      await QuotaService.instance.refreshQuota();

      expect(upgradeCallbackCount, equals(0));
    });

    test('does not fire when downgrading from premium to free', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('premium'));

      int upgradeCallbackCount = 0;
      QuotaService.instance.onTierUpgradedToPremium = () {
        upgradeCallbackCount++;
      };

      mockClient.mockQuotaStatus = _buildStatus('free');
      await QuotaService.instance.refreshQuota();

      expect(upgradeCallbackCount, equals(0));
      expect(QuotaService.instance.tier, equals('free'));
      expect(QuotaService.instance.lastKnownTier, equals('free'));
    });
  });

  group('CloudSyncService Progressive Line Items Re-sync', () {
    test('reSyncReceiptsForPremium executes batches and saves them to ReceiptRepository', () async {
      const username = 'premium_user';
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_premium_123',
        username: username,
        email: 'premium@example.com',
        createdAt: '2026-10-17T00:00:00Z',
      ));
      QuotaService.instance.setStatusForTesting(_buildStatus('premium'));

      final batch1 = List.generate(50, (i) => _buildReceiptRecord('rec_$i', 3));
      final batch2 = List.generate(15, (i) => _buildReceiptRecord('rec_${50 + i}', 2));

      mockClient.onFetchReceipts = (u, limit, offset) async {
        if (offset == 0) return batch1;
        if (offset == 50) return batch2;
        return [];
      };

      await CloudSyncService.instance.reSyncReceiptsForPremium();

      expect(mockClient.fetchReceiptsCalls.length, equals(2));
      expect(mockClient.fetchReceiptsCalls[0].offset, equals(0));
      expect(mockClient.fetchReceiptsCalls[0].limit, equals(50));
      expect(mockClient.fetchReceiptsCalls[1].offset, equals(50));
      expect(mockClient.fetchReceiptsCalls[1].limit, equals(50));

      // Verify all 65 receipts are saved in ReceiptRepository with line items intact
      final localReceipts = ReceiptRepository.instance.receipts;
      expect(localReceipts.length, equals(65));
      expect(localReceipts.firstWhere((r) => r.id == 'rec_0').lineItems.length, equals(3));
      expect(localReceipts.firstWhere((r) => r.id == 'rec_50').lineItems.length, equals(2));

      // Verify SharedPreferences timestamp updated
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_sync_timestamp_$username');
      expect(lastSync, isNotNull);
      expect(DateTime.tryParse(lastSync!), isNotNull);

      // Verify lock state reset
      expect(CloudSyncService.instance.isReSyncingForPremium, isFalse);
    });

    test('concurrency locking prevents duplicate concurrent reSync loops', () async {
      const username = 'premium_concurrency_user';
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_premium_concurrency',
        username: username,
        email: 'concurrency@example.com',
        createdAt: '2026-10-17T00:00:00Z',
      ));
      QuotaService.instance.setStatusForTesting(_buildStatus('premium'));

      final completer = Completer<List<ReceiptRecordDto>>();
      mockClient.onFetchReceipts = (u, limit, offset) => completer.future;

      // Launch first sync operation
      final firstSyncFuture = CloudSyncService.instance.reSyncReceiptsForPremium();
      expect(CloudSyncService.instance.isReSyncingForPremium, isTrue);

      // Launch second concurrent sync operation while first is in-flight
      final secondSyncFuture = CloudSyncService.instance.reSyncReceiptsForPremium();

      // Complete the network request
      completer.complete([_buildReceiptRecord('concurrency_rec_1', 1)]);

      await Future.wait([firstSyncFuture, secondSyncFuture]);

      // fetchReceipts should have been called only once, second call bailed out due to lock
      expect(mockClient.fetchReceiptsCalls.length, equals(1));
      expect(CloudSyncService.instance.isReSyncingForPremium, isFalse);
    });

    test('reSyncReceiptsForPremium guards against unauthenticated user', () async {
      QuotaService.instance.setStatusForTesting(_buildStatus('premium'));
      expect(AuthService.instance.isLoggedIn, isFalse);

      await CloudSyncService.instance.reSyncReceiptsForPremium();

      expect(mockClient.fetchReceiptsCalls, isEmpty);
      expect(CloudSyncService.instance.isReSyncingForPremium, isFalse);
    });

    test('reSyncReceiptsForPremium guards against free tier', () async {
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_free_guard',
        username: 'free_guard_user',
        email: 'free_guard@example.com',
        createdAt: '2026-10-17T00:00:00Z',
      ));
      QuotaService.instance.setStatusForTesting(_buildStatus('free'));

      await CloudSyncService.instance.reSyncReceiptsForPremium();

      expect(mockClient.fetchReceiptsCalls, isEmpty);
      expect(CloudSyncService.instance.isReSyncingForPremium, isFalse);
    });

    test('end-to-end observer wiring: tier upgrade triggers reSyncReceiptsForPremium', () async {
      const username = 'wired_user';
      mockClient.mockQuotaStatus = _buildStatus('free');

      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr_wired_123',
        username: username,
        email: 'wired@example.com',
        createdAt: '2026-10-17T00:00:00Z',
      ));

      // Wait for any background quota refresh from saveSession to complete
      while (QuotaService.instance.isLoading) {
        await Future.delayed(Duration.zero);
      }

      // Wire observer via CloudSyncService init
      CloudSyncService.instance.init();
      expect(QuotaService.instance.onTierUpgradedToPremium, isNotNull);
      expect(QuotaService.instance.tier, equals('free'));
      expect(QuotaService.instance.lastKnownTier, equals('free'));

      // Backend now reports user upgraded to premium tier
      mockClient.mockQuotaStatus = _buildStatus('premium');
      mockClient.onFetchReceipts = (u, limit, offset) async {
        return [_buildReceiptRecord('wired_rec_1', 4)];
      };

      // Refreshing quota detects free -> premium and triggers line items re-sync
      await QuotaService.instance.refreshQuota();

      // Wait for re-sync loop to complete
      while (CloudSyncService.instance.isReSyncingForPremium) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(mockClient.fetchReceiptsCalls.isNotEmpty, isTrue);
      expect(ReceiptRepository.instance.receipts.length, equals(1));
      expect(ReceiptRepository.instance.receipts.first.lineItems.length, equals(4));
    });
  });
}

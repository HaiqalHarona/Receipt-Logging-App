// lib/services/cloud_sync_service.dart
//
// Singleton service managing initial cloud data sync on login (user profile,
// initial 50 receipts, conversation list, top 3 chat message pre-fetches),
// progressive background historical hydration (50-item batches at 1s intervals),
// and fast delta-syncing for returning sessions.

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger_service.dart';
import '../cloud/api/backend_api_client.dart';
import '../cloud/services/auth_service.dart';
import '../data/mappers/chat_message_mapper.dart';
import '../data/mappers/conversation_mapper.dart';
import '../data/repositories/chat_message_repository.dart';
import '../data/repositories/conversation_repository.dart';
import '../data/repositories/receipt_repository.dart';
import '../domain/models/line_item.dart';
import '../domain/models/receipt.dart';
import '../cloud/models/receipt_models.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const String _keyFullSyncPrefix = 'full_cloud_sync_complete_';
  static const String _keyLastSyncPrefix = 'last_sync_timestamp_';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isHydrating = false;
  bool get isHydrating => _isHydrating;

  int _activeSessionId = 0;

  /// Cancels any in-flight background hydration loop (e.g. upon user logout).
  void cancelBackgroundSync() {
    _activeSessionId++;
    _isHydrating = false;
    _isSyncing = false;
    AppLogger.info('CloudSync', 'Background sync cancelled.');
  }

  /// Resets the full sync state for a user (e.g. during test resets or account migration).
  Future<void> resetSyncState(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyFullSyncPrefix$username');
      await prefs.remove('$_keyLastSyncPrefix$username');
      AppLogger.info('CloudSync', 'Sync state reset for user $username.');
    } catch (e, st) {
      AppLogger.error('CloudSync', 'Failed to reset sync state', e, st);
    }
  }

  /// Performs initial cloud data sync upon login or app boot if signed in:
  /// 1. Fetches user profile via `GET /user/me`
  /// 2. Fetches conversation list (`GET /chat/list?limit=20`) -> Isar DB
  /// 3. Pre-fetches chat history for the top 3 most recent conversations
  /// 4. If full sync completed previously: runs fast Delta Sync (`GET /receipts/?updated_after=...`)
  /// 5. If first time: fetches initial 50 receipts for instant UI render, then spawns
  ///    progressive background hydration loop (50 receipts per 1s) to backfill history.
  Future<void> syncOnLogin() async {
    if (!AuthService.instance.isLoggedIn) return;
    if (_isSyncing) return;

    _isSyncing = true;
    final sessionId = ++_activeSessionId;

    try {
      final username = AuthService.instance.currentUsername;
      final token = AuthService.instance.currentUserToken;
      if (username == null || token == null) return;

      AppLogger.info('CloudSync',
          'Starting login sync for user $username (session: $sessionId)...');

      // ── 1. Fetch User Profile ──────────────────────────────────────────────
      await AuthService.instance.getOrFetchProfile();

      // ── 2. Conversations Load (Limit 20) ───────────────────────────────────
      final convDtos = await BackendApiClient.instance.fetchConversations(
        username: username,
        userToken: token,
        limit: 20,
        offset: 0,
      );
      if (convDtos.isNotEmpty) {
        final domainConvs = convDtos.map((dto) => dto.toDomain()).toList();
        await ConversationRepository.instance.saveBatch(domainConvs);

        // ── 3. Pre-fetch Messages for Top 3 Conversations ───────────────────
        for (final conv in convDtos.take(3)) {
          if (_activeSessionId != sessionId || !AuthService.instance.isLoggedIn)
            break;
          await ensureChatHistoryLoaded(conv.id);
        }
      }

      // ── 4. Receipts Sync (Delta vs Progressive Hydration) ───────────────────
      final prefs = await SharedPreferences.getInstance();
      final hasLocalReceipts = ReceiptRepository.instance.receipts.isNotEmpty;
      final isFullSyncComplete =
          (prefs.getBool('$_keyFullSyncPrefix$username') ?? false) &&
              hasLocalReceipts;

      if (isFullSyncComplete) {
        AppLogger.info('CloudSync',
            'Full sync previously completed for $username and local receipts present (${ReceiptRepository.instance.receipts.length}). Running delta sync...');
        await _runDeltaSync(username, token, prefs);
      } else {
        AppLogger.info('CloudSync',
            'No local receipts or full sync incomplete for $username. Fetching initial 50 receipts for instant render...');
        // Clear stale timestamps so subsequent logic is consistent
        await prefs.remove('$_keyFullSyncPrefix$username');
        await prefs.remove('$_keyLastSyncPrefix$username');

        final initialLoaded = await fetchMoreReceipts(offset: 0, limit: 50);

        if (initialLoaded < 50) {
          // Total historical records on server is less than 50 -> complete immediately!
          await prefs.setBool('$_keyFullSyncPrefix$username', true);
          await prefs.setString('$_keyLastSyncPrefix$username',
              DateTime.now().toUtc().toIso8601String());
          AppLogger.info('CloudSync',
              'Initial batch ($initialLoaded) covered all records. Full sync marked complete.');
        } else {
          // Launch non-blocking background hydration loop for the rest of history
          unawaited(_startBackgroundReceiptHydration(
            username: username,
            userToken: token,
            startOffset: 50,
            chunkSize: 50,
            sessionId: sessionId,
          ));
        }
      }

      AppLogger.info('CloudSync', 'Login sync phase 1 completed successfully.');
    } catch (e, st) {
      AppLogger.error('CloudSync', 'syncOnLogin error', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Non-blocking background loop that fetches historical receipts in chunks
  /// with a 1-second interval until the server returns an empty or partial page.
  Future<void> _startBackgroundReceiptHydration({
    required String username,
    required String userToken,
    required int startOffset,
    required int chunkSize,
    required int sessionId,
  }) async {
    if (_isHydrating) return;
    _isHydrating = true;
    int currentOffset = startOffset;

    AppLogger.info('CloudSync',
        'Starting background receipt hydration from offset $currentOffset...');

    try {
      final prefs = await SharedPreferences.getInstance();

      while (AuthService.instance.isLoggedIn && _activeSessionId == sessionId) {
        // 1-second polite pause between chunks to keep UI 60/120fps smooth & prevent rate limits
        await Future.delayed(const Duration(seconds: 1));

        if (!AuthService.instance.isLoggedIn || _activeSessionId != sessionId) {
          AppLogger.info('CloudSync',
              'Background hydration aborted (user logged out or session changed).');
          break;
        }

        final loaded =
            await fetchMoreReceipts(offset: currentOffset, limit: chunkSize);
        AppLogger.info('CloudSync',
            'Background hydrated $loaded receipts (offset: $currentOffset)');

        if (loaded < chunkSize) {
          // Reached end of historical records!
          await prefs.setBool('$_keyFullSyncPrefix$username', true);
          await prefs.setString('$_keyLastSyncPrefix$username',
              DateTime.now().toUtc().toIso8601String());
          AppLogger.info('CloudSync',
              'Full historical receipt hydration COMPLETE. Stored in local Isar DB.');
          break;
        }

        currentOffset += loaded;
      }
    } catch (e, st) {
      AppLogger.error(
          'CloudSync', 'Error in background receipt hydration', e, st);
    } finally {
      _isHydrating = false;
    }
  }

  /// Fast Delta Sync: Fetches only receipts created/updated after the last sync timestamp.
  Future<void> _runDeltaSync(
    String username,
    String token,
    SharedPreferences prefs,
  ) async {
    try {
      if (ReceiptRepository.instance.receipts.isEmpty) {
        AppLogger.warning('CloudSync',
            'Delta sync aborted because local receipts are empty. Triggering initial load...');
        await fetchMoreReceipts(offset: 0, limit: 50);
        return;
      }

      final lastSyncStr = prefs.getString('$_keyLastSyncPrefix$username');
      AppLogger.info(
          'CloudSync', 'Executing delta sync (updated_after: $lastSyncStr)...');

      final recordDtos = await BackendApiClient.instance.fetchReceipts(
        username: username,
        userToken: token,
        updatedAfter: lastSyncStr,
      );

      if (recordDtos.isNotEmpty) {
        final domainReceipts =
            recordDtos.map((record) => _recordDtoToDomain(record)).toList();
        await ReceiptRepository.instance.saveBatchFromCloud(domainReceipts);
        AppLogger.info('CloudSync',
            'Delta sync updated ${domainReceipts.length} receipts in Isar DB.');
      } else {
        AppLogger.info(
            'CloudSync', 'Delta sync: local cache already up to date.');
      }

      await prefs.setString('$_keyLastSyncPrefix$username',
          DateTime.now().toUtc().toIso8601String());
    } catch (e, st) {
      AppLogger.error('CloudSync', 'Delta sync error', e, st);
    }
  }

  /// Lazy loads the next page of receipts from `GET /receipts/?limit=$limit&offset=$offset`
  /// and saves them into local Isar DB. Returns the count of receipts loaded.
  Future<int> fetchMoreReceipts({required int offset, int limit = 50}) async {
    final username = AuthService.instance.currentUsername;
    final token = AuthService.instance.currentUserToken;
    if (username == null || token == null) {
      AppLogger.warning(
          'CloudSync', 'fetchMoreReceipts skipped: username or token null');
      return 0;
    }

    try {
      AppLogger.info('CloudSync',
          'Executing fetchReceipts for user $username (offset: $offset, limit: $limit)...');
      final recordDtos = await BackendApiClient.instance.fetchReceipts(
        username: username,
        userToken: token,
        limit: limit,
        offset: offset,
      );

      if (recordDtos.isEmpty) {
        AppLogger.info(
            'CloudSync', 'fetchReceipts returned 0 records (offset: $offset)');
        return 0;
      }

      final domainReceipts =
          recordDtos.map((record) => _recordDtoToDomain(record)).toList();
      await ReceiptRepository.instance.saveBatchFromCloud(domainReceipts);
      AppLogger.info('CloudSync',
          'Loaded ${domainReceipts.length} receipts into Isar DB (offset: $offset)');
      return domainReceipts.length;
    } catch (e, st) {
      AppLogger.error(
          'CloudSync', 'fetchMoreReceipts failed with exception', e, st);
      return 0;
    }
  }

  /// Lazy loads message history for [conversationId] via `GET /chat/history`
  /// if local messages in Isar DB are missing/empty.
  Future<void> ensureChatHistoryLoaded(String conversationId,
      {int limit = 50}) async {
    final username = AuthService.instance.currentUsername;
    final token = AuthService.instance.currentUserToken;
    if (username == null || token == null) return;

    try {
      final messageDtos = await BackendApiClient.instance.fetchChatHistory(
        conversationId: conversationId,
        username: username,
        userToken: token,
        limit: limit,
        offset: 0,
      );

      if (messageDtos.isNotEmpty) {
        final domainMessages =
            messageDtos.map((dto) => dto.toDomain()).toList();
        await ChatMessageRepository.instance.saveBatch(domainMessages);
        AppLogger.info('CloudSync',
            'Loaded ${domainMessages.length} messages for conversation $conversationId');
      }
    } catch (e, st) {
      AppLogger.error('CloudSync', 'ensureChatHistoryLoaded error', e, st);
    }
  }

  Receipt _recordDtoToDomain(ReceiptRecordDto record) {
    final r = record.receipt;
    return Receipt(
      id: record.id,
      merchant: r.merchantName,
      date: r.date,
      amount: r.totalAmount,
      currency: r.currency,
      category: r.category ?? '',
      imagePath: record.receiptImagePath,
      createdAt: DateTime.tryParse(record.createdAt)?.toUtc(),
      lineItems: r.lineItems
          .map((l) => LineItem(
                description: l.description,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                totalPrice: l.totalPrice,
              ))
          .toList(),
    );
  }
}

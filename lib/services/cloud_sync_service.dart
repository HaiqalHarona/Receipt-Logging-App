// lib/services/cloud_sync_service.dart
//
// Singleton service managing initial cloud data sync on login (user profile,
// receipts limit 20, conversation list limit 20) and lazy-loading pagination.

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

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Performs initial cloud data sync upon login or app boot if signed in:
  /// 1. Fetches user profile via `GET /user/me`
  /// 2. If local receipts are empty, fetches initial receipts page (`GET /receipts/?limit=20`) -> Isar DB
  /// 3. If local conversations are empty, fetches initial conversation list (`GET /chat/list?limit=20`) -> Isar DB
  Future<void> syncOnLogin() async {
    if (!AuthService.instance.isLoggedIn) return;
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      final username = AuthService.instance.currentUsername;
      final token = AuthService.instance.currentUserToken;
      if (username == null || token == null) return;

      // ── 1. Fetch User Profile ──────────────────────────────────────────────
      await AuthService.instance.getOrFetchProfile();

      // ── 2. Initial Receipts Load (Limit 20) ────────────────────────────────
      await fetchMoreReceipts(offset: 0, limit: 20);

      // ── 3. Initial Conversations Load (Limit 20) ───────────────────────────
      final convDtos = await BackendApiClient.instance.fetchConversations(
        username: username,
        userToken: token,
        limit: 20,
        offset: 0,
      );
      if (convDtos.isNotEmpty) {
        final domainConvs = convDtos.map((dto) => dto.toDomain()).toList();
        await ConversationRepository.instance.saveBatch(domainConvs);
      }

      AppLogger.info('CloudSync', 'Login sync completed successfully');
    } catch (e, st) {
      AppLogger.error('CloudSync', 'syncOnLogin error', e, st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Lazy loads the next page of receipts from `GET /receipts/?limit=$limit&offset=$offset`
  /// and saves them into local Isar DB. Returns the count of receipts loaded.
  Future<int> fetchMoreReceipts({required int offset, int limit = 20}) async {
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
        AppLogger.info('CloudSync', 'fetchReceipts returned 0 records');
        return 0;
      }

      final domainReceipts =
          recordDtos.map((record) => _recordDtoToDomain(record)).toList();
      await ReceiptRepository.instance.saveAllReceipts(domainReceipts);
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

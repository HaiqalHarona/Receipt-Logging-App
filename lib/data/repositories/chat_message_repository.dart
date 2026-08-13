import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../services/app_logger_service.dart';
import '../../services/isar_service.dart';
import '../models/chat_message_isar.dart';
import '../mappers/chat_message_mapper.dart';
import '../../domain/models/chat_message.dart';
import '../../services/cloud_sync_service.dart';
import 'conversation_repository.dart';

class ChatMessageRepository extends ChangeNotifier {
  ChatMessageRepository._();

  static final ChatMessageRepository instance = ChatMessageRepository._();

  List<ChatMessage> _currentHistory = [];
  String? _activeConversationId;
  bool _isInitialized = false;

  /// Immutable snapshot of messages for the currently loaded conversation,
  /// sorted chronologically (oldest first).
  List<ChatMessage> get currentHistory => List.unmodifiable(_currentHistory);

  /// The conversation ID whose history is currently cached.
  String? get activeConversationId => _activeConversationId;

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;
    AppLogger.info('Isar', '[ChatMessageRepository] Initializing chat message repository...');
    _isInitialized = true;
  }

  // ── HISTORY OPERATIONS ───────────────────────────────────────────────────────

  /// Loads messages for [conversationId] into [currentHistory].
  ///
  /// Messages are sorted chronologically (oldest first) — suitable for
  /// rendering a chat timeline from top to bottom.
  ///
  /// [limit]  — max messages to load (default 100 for local Isar; paginate for large histories).
  /// [offset] — pagination offset (for loading older messages on scroll).
  Future<List<ChatMessage>> fetchHistory(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (!IsarService.isInitialized) {
      AppLogger.warning('Isar', '[ChatMessageRepository] fetchHistory called before IsarService initialized');
      return [];
    }

    try {
      AppLogger.debug('Isar', '[ChatMessageRepository] Querying chat messages for conversation $conversationId (offset: $offset, limit: $limit)');
      var isarModels = await IsarService.isar.chatMessageIsarModels
          .where()
          .conversationIdEqualTo(conversationId)
          .findAll();
      AppLogger.debug('Isar', '[ChatMessageRepository] Query result: found ${isarModels.length} local messages for conversation $conversationId.');

      // If no local messages exist for this conversation, lazy load from backend
      if (isarModels.isEmpty && offset == 0) {
        AppLogger.info('Isar', '[ChatMessageRepository] No local messages for $conversationId, triggering cloud sync lazy load...');
        await CloudSyncService.instance.ensureChatHistoryLoaded(conversationId);
        isarModels = await IsarService.isar.chatMessageIsarModels
            .where()
            .conversationIdEqualTo(conversationId)
            .findAll();
        AppLogger.debug('Isar', '[ChatMessageRepository] Post-sync query result: found ${isarModels.length} messages for conversation $conversationId.');
      }

      // Sort chronologically (oldest first) in Dart
      isarModels.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Apply pagination offset & limit in Dart if specified
      final paginated = isarModels.skip(offset).take(limit).toList();
      final messages = paginated.map((m) => m.toDomain()).toList();

      // Update in-memory cache when loading the same conversation
      if (_activeConversationId == conversationId || offset == 0) {
        _activeConversationId = conversationId;
        _currentHistory = messages;
        notifyListeners();
      }

      AppLogger.info('Isar', '[ChatMessageRepository] Fetched ${messages.length} messages for conversation $conversationId.');
      return messages;
    } catch (e, stackTrace) {
      AppLogger.error('Isar', '[ChatMessageRepository] fetchHistory error', e, stackTrace);
      return [];
    }
  }

  // ── MESSAGE WRITE OPERATIONS ─────────────────────────────────────────────────

  /// Creates, persists, and appends a new message to [currentHistory].
  ///
  /// Also calls [ConversationRepository.touchUpdatedAt] so the parent
  /// conversation rises to the top of the conversation list.
  ///
  /// [id]    — optional backend UUID; generates a local-only ID if null.
  Future<ChatMessage> addMessage({
    required String conversationId,
    required String sender,
    required String content,
    String? id,
  }) async {
    final now = DateTime.now();
    final messageId = id ?? 'local_msg_${now.millisecondsSinceEpoch}';

    final model = ChatMessageIsarModel()
      ..messageId = messageId
      ..conversationId = conversationId
      ..sender = sender
      ..content = content
      ..createdAt = now;

    if (IsarService.isInitialized) {
      AppLogger.info('Isar', '[ChatMessageRepository] Transaction write: adding message $messageId (sender: $sender) to conversation $conversationId');
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.chatMessageIsarModels.put(model);
      });
      AppLogger.debug('Isar', '[ChatMessageRepository] Saved message $messageId to Isar DB.');
    } else {
      AppLogger.debug('Isar', '[ChatMessageRepository] Isar not initialized; message $messageId added in-memory only.');
    }

    final message = model.toDomain();

    // Set active conversation ID if null or matches
    if (_activeConversationId == null || _activeConversationId == conversationId) {
      _activeConversationId = conversationId;
      _currentHistory = [..._currentHistory, message];
    }

    // Keep parent conversation's updatedAt in sync
    await ConversationRepository.instance.touchUpdatedAt(conversationId);

    notifyListeners();
    return message;
  }

  /// Persists multiple messages in a single Isar transaction.
  /// Useful when syncing backend history into local storage.
  Future<void> saveBatch(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;

    if (IsarService.isInitialized) {
      AppLogger.info('Isar', '[ChatMessageRepository] Transaction write: batch saving ${messages.length} chat messages');
      await IsarService.isar.writeTxn(() async {
        final models = messages.map((m) => m.toIsar()).toList();
        await IsarService.isar.chatMessageIsarModels.putAll(models);
      });
      AppLogger.debug('Isar', '[ChatMessageRepository] Batch saved ${messages.length} messages to Isar DB.');
    }

    // Refresh cache if the batch touches the active conversation
    final touchedConversations = messages.map((m) => m.conversationId).toSet();
    if (_activeConversationId != null &&
        touchedConversations.contains(_activeConversationId)) {
      await fetchHistory(_activeConversationId!);
    } else {
      notifyListeners();
    }
  }

  /// Deletes all locally stored messages belonging to [conversationId].
  /// Typically called before or after softDeleting the parent conversation.
  Future<void> deleteHistoryForConversation(String conversationId) async {
    if (IsarService.isInitialized) {
      AppLogger.info('Isar', '[ChatMessageRepository] Transaction write: deleting chat history for conversation $conversationId');
      await IsarService.isar.writeTxn(() async {
        final allMsgs = await IsarService.isar.chatMessageIsarModels
            .where()
            .findAll();
        final ids = allMsgs
            .where((m) => m.conversationId == conversationId)
            .map((m) => m.id)
            .toList();
        AppLogger.debug('Isar', '[ChatMessageRepository] Query result: found ${ids.length} messages to delete for conversation $conversationId');
        await IsarService.isar.chatMessageIsarModels.deleteAll(ids);
      });
      AppLogger.debug('Isar', '[ChatMessageRepository] Deleted chat history for conversation $conversationId from Isar DB.');
    }

    if (_activeConversationId == conversationId) {
      _currentHistory = [];
      _activeConversationId = null;
    }

    notifyListeners();
  }

  /// Wipes all chat messages from Isar DB (called on logout/account reset).
  Future<void> clearAll() async {
    if (IsarService.isInitialized) {
      AppLogger.info('Isar', '[ChatMessageRepository] Transaction write: clearing chatMessageIsarModels collection');
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.chatMessageIsarModels.clear();
      });
      AppLogger.debug('Isar', '[ChatMessageRepository] Cleared all chat messages from Isar DB.');
    }
    _currentHistory = [];
    _activeConversationId = null;
    notifyListeners();
  }
}


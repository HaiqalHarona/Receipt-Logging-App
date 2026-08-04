import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../services/isar_service.dart';
import '../models/chat_message_isar.dart';
import '../mappers/chat_message_mapper.dart';
import '../../domain/models/chat_message.dart';
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
    if (!IsarService.isInitialized) return [];

    try {
      final isarModels = await IsarService.isar.chatMessageIsarModels
          .where()
          .conversationIdEqualTo(conversationId)
          .findAll();

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

      return messages;
    } catch (e) {
      debugPrint('⚠️ [ChatMessageRepository] fetchHistory error: $e');
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
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.chatMessageIsarModels.put(model);
      });
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
      await IsarService.isar.writeTxn(() async {
        final models = messages.map((m) => m.toIsar()).toList();
        await IsarService.isar.chatMessageIsarModels.putAll(models);
      });
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
      await IsarService.isar.writeTxn(() async {
        final allMsgs = await IsarService.isar.chatMessageIsarModels
            .where()
            .findAll();
        final ids = allMsgs
            .where((m) => m.conversationId == conversationId)
            .map((m) => m.id)
            .toList();
        await IsarService.isar.chatMessageIsarModels.deleteAll(ids);
      });
    }

    if (_activeConversationId == conversationId) {
      _currentHistory = [];
      _activeConversationId = null;
    }

    notifyListeners();
  }
}

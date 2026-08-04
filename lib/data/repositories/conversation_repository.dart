// lib/data/repositories/conversation_repository.dart
//
// Single source of truth for conversation data (local Isar DB).
//
// Implements the Repository pattern with reactive ChangeNotifier notifications
// so ViewModels and Riverpod providers automatically rebuild when conversations
// are created, updated, or soft-deleted.
//
// Public API:
//   [conversations]                           — immutable snapshot of active conversations
//   [init()]                                  — load from Isar on app startup
//   [createConversation({title, id})]         — insert a new conversation
//   [updateTitle(id, newTitle)]               — rename a conversation
//   [touchUpdatedAt(id)]                      — bump updatedAt (called by ChatMessageRepository)
//   [softDeleteConversation(id)]              — set deletedAt (hides from active list)
//   [clearAll()]                              — wipe all conversations (settings/sign-out)

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../services/isar_service.dart';
import '../models/conversation_isar.dart';
import '../mappers/conversation_mapper.dart';
import '../../domain/models/conversation.dart';

class ConversationRepository extends ChangeNotifier {
  ConversationRepository._();

  static final ConversationRepository instance = ConversationRepository._();

  List<Conversation> _conversations = [];
  bool _isInitialized = false;

  /// Returns an immutable snapshot of all active (non-deleted) conversations,
  /// sorted by [updatedAt] descending (most recently active first).
  List<Conversation> get conversations =>
      List.unmodifiable(_conversations.where((c) => c.isActive));

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────────

  /// Initializes the repository by loading conversations from Isar.
  /// Safe to call multiple times — only loads once.
  Future<void> init() async {
    if (_isInitialized) return;
    if (IsarService.isInitialized) {
      try {
        await _loadFromIsar();
      } catch (e) {
        debugPrint('⚠️ [ConversationRepository] Init error: $e');
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  // ── CRUD OPERATIONS ───────────────────────────────────────────────────────────

  /// Creates and persists a new conversation.
  ///
  /// [id]    — optional backend UUID; a local-only ID is generated if null.
  /// [title] — conversation display title (defaults to 'New Conversation').
  Future<Conversation> createConversation({
    String? id,
    String title = 'New Conversation',
  }) async {
    final now = DateTime.now();
    final conversationId = id ?? 'local_${now.millisecondsSinceEpoch}';

    final model = ConversationIsarModel()
      ..conversationId = conversationId
      ..title = title
      ..createdAt = now
      ..updatedAt = now;

    if (IsarService.isInitialized) {
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.conversationIsarModels.put(model);
      });
      await _loadFromIsar();
    } else {
      final conversation = model.toDomain();
      _conversations.insert(0, conversation);
    }

    notifyListeners();
    return model.toDomain();
  }

  /// Updates the title of a conversation and bumps [updatedAt].
  Future<void> updateTitle(String id, String newTitle) async {
    await _mutateConversation(id, (model) {
      model.title = newTitle;
      model.updatedAt = DateTime.now();
    });
  }

  /// Bumps [updatedAt] on a conversation (called when a new message is sent).
  Future<void> touchUpdatedAt(String id) async {
    await _mutateConversation(id, (model) {
      model.updatedAt = DateTime.now();
    });
  }

  /// Soft-deletes a conversation by setting [deletedAt].
  /// The conversation is removed from the active [conversations] list.
  Future<void> softDeleteConversation(String id) async {
    await _mutateConversation(id, (model) {
      model.deletedAt = DateTime.now();
    });
  }

  /// Permanently wipes all conversations from the local Isar database.
  Future<void> clearAll() async {
    if (IsarService.isInitialized) {
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.conversationIsarModels.clear();
      });
      await _loadFromIsar();
    } else {
      _conversations.clear();
    }
    notifyListeners();
  }

  // ── INTERNAL ──────────────────────────────────────────────────────────────────

  Future<void> _loadFromIsar() async {
    try {
      final all = await IsarService.isar.conversationIsarModels
          .where()
          .findAll();
      // Filter active (non-deleted), sort by updatedAt descending in Dart
      final active = all.where((m) => m.deletedAt == null).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _conversations = active.map((m) => m.toDomain()).toList();
    } catch (e) {
      debugPrint('⚠️ [ConversationRepository] Load error: $e');
      _conversations = [];
    }
  }

  /// Finds a conversation by [id], applies [mutator], persists, and reloads.
  Future<void> _mutateConversation(
    String id,
    void Function(ConversationIsarModel model) mutator,
  ) async {
    if (IsarService.isInitialized) {
      await IsarService.isar.writeTxn(() async {
        final existing = await IsarService.isar.conversationIsarModels
            .where()
            .conversationIdEqualTo(id)
            .findFirst();
        if (existing != null) {
          mutator(existing);
          await IsarService.isar.conversationIsarModels.put(existing);
        }
      });
      await _loadFromIsar();
    } else {
      final index = _conversations.indexWhere((c) => c.id == id);
      if (index >= 0) {
        final model = _conversations[index].toIsar();
        mutator(model);
        _conversations[index] = model.toDomain();
      }
    }
    notifyListeners();
  }
}

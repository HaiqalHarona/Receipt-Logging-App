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
import '../../cloud/api/backend_api_client.dart';
import '../../cloud/services/auth_service.dart';
import '../../services/app_logger_service.dart';
import '../../services/isar_service.dart';
import '../models/conversation_isar.dart';
import '../mappers/conversation_mapper.dart';
import '../../domain/models/conversation.dart';

class ConversationRepository extends ChangeNotifier {
  ConversationRepository._() {
    AuthService.instance.addListener(() {
      notifyListeners();
    });
  }

  static final ConversationRepository instance = ConversationRepository._();

  List<Conversation> _conversations = [];
  bool _isInitialized = false;

  /// Returns an immutable snapshot of all active (non-deleted) conversations,
  /// sorted by [updatedAt] descending (most recently active first).
  /// When unauthenticated (guest mode), filters out any cloud user conversations (UUIDs).
  List<Conversation> get conversations {
    if (!AuthService.instance.isLoggedIn) {
      return List.unmodifiable(_conversations
          .where((c) => c.isActive && !_isUuid(c.id)));
    }
    return List.unmodifiable(_conversations.where((c) => c.isActive));
  }

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────────

  /// Initializes the repository by loading conversations from Isar.
  /// Safe to call multiple times — only loads once.
  Future<void> init() async {
    if (_isInitialized && _conversations.isNotEmpty) return;
    AppLogger.info('Isar',
        '[ConversationRepository] Initializing conversation repository...');
    if (IsarService.isInitialized) {
      try {
        await _loadFromIsar();
        _isInitialized = true;
        AppLogger.info('Isar',
            '[ConversationRepository] Initialized successfully with ${_conversations.length} active conversations.');
      } catch (e, stackTrace) {
        AppLogger.error(
            'Isar', '[ConversationRepository] Init error', e, stackTrace);
      }
    } else {
      AppLogger.warning('Isar',
          '[ConversationRepository] IsarService not initialized yet; deferring init.');
    }
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
      AppLogger.info('Isar',
          '[ConversationRepository] Transaction write: creating conversation $conversationId ("$title")');
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.conversationIsarModels.put(model);
      });
      AppLogger.debug('Isar',
          '[ConversationRepository] Saved conversation $conversationId to Isar DB.');
      await _loadFromIsar();
    } else {
      final conversation = model.toDomain();
      _conversations.insert(0, conversation);
      AppLogger.debug('Isar',
          '[ConversationRepository] Saved conversation $conversationId to in-memory store.');
    }

    notifyListeners();
    return model.toDomain();
  }

  bool _isUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  void _updateCloudTitleIfSynced(String conversationId, String newTitle) {
    if (_isUuid(conversationId) && AuthService.instance.isLoggedIn) {
      final username = AuthService.instance.currentUsername;
      final userToken = AuthService.instance.currentUserToken;
      if (username != null && userToken != null) {
        AppLogger.info('CloudSync',
            '[ConversationRepository] Triggering backend PATCH /chat/$conversationId on Supabase (title: "$newTitle")...');
        BackendApiClient.instance
            .updateConversationTitle(
          conversationId: conversationId,
          title: newTitle,
          username: username,
          userToken: userToken,
        )
            .then((record) {
          AppLogger.info('CloudSync',
              '[ConversationRepository] Cloud conversation $conversationId title updated on Supabase (title="${record.title}").');
        }).catchError((e, st) {
          AppLogger.error(
              'CloudSync',
              '[ConversationRepository] Error executing PATCH /chat/$conversationId',
              e,
              st);
        });
      }
    }
  }

  void _deleteFromCloudIfSynced(String conversationId) {
    if (_isUuid(conversationId) && AuthService.instance.isLoggedIn) {
      final username = AuthService.instance.currentUsername;
      final userToken = AuthService.instance.currentUserToken;
      if (username != null && userToken != null) {
        AppLogger.info('CloudSync',
            '[ConversationRepository] Triggering backend DELETE /chat/$conversationId on Supabase...');
        BackendApiClient.instance
            .deleteConversation(
          conversationId: conversationId,
          username: username,
          userToken: userToken,
        )
            .then((success) {
          if (success) {
            AppLogger.info('CloudSync',
                '[ConversationRepository] Cloud conversation $conversationId soft-deleted on Supabase.');
          } else {
            AppLogger.warning('CloudSync',
                '[ConversationRepository] Cloud conversation $conversationId deletion returned false.');
          }
        }).catchError((e, st) {
          AppLogger.error(
              'CloudSync',
              '[ConversationRepository] Error executing DELETE /chat/$conversationId',
              e,
              st);
        });
      }
    }
  }

  /// Updates the title of a conversation and bumps [updatedAt].
  Future<void> updateTitle(String id, String newTitle) async {
    AppLogger.info('Isar',
        '[ConversationRepository] Updating conversation $id title to "$newTitle"');
    await _mutateConversation(id, (model) {
      model.title = newTitle;
      model.updatedAt = DateTime.now();
    });
    _updateCloudTitleIfSynced(id, newTitle);
  }

  /// Bumps [updatedAt] on a conversation (called when a new message is sent).
  Future<void> touchUpdatedAt(String id) async {
    AppLogger.debug('Isar',
        '[ConversationRepository] Touching updatedAt for conversation $id');
    await _mutateConversation(id, (model) {
      model.updatedAt = DateTime.now();
    });
  }

  /// Soft-deletes a conversation by setting [deletedAt].
  /// The conversation is removed from the active [conversations] list.
  Future<void> softDeleteConversation(String id) async {
    AppLogger.info(
        'Isar', '[ConversationRepository] Soft-deleting conversation $id');
    await _mutateConversation(id, (model) {
      model.deletedAt = DateTime.now();
    });
    _deleteFromCloudIfSynced(id);
  }

  /// Permanently wipes all conversations from the local Isar database.
  Future<void> clearAll() async {
    if (IsarService.isInitialized) {
      AppLogger.info('Isar',
          '[ConversationRepository] Transaction write: clearing conversationIsarModels collection');
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.conversationIsarModels.clear();
      });
      AppLogger.debug('Isar',
          '[ConversationRepository] Cleared all conversations from Isar DB.');
      await _loadFromIsar();
    } else {
      _conversations.clear();
      AppLogger.debug('Isar',
          '[ConversationRepository] Cleared all conversations from in-memory store.');
    }
    notifyListeners();
  }

  // ── INTERNAL ──────────────────────────────────────────────────────────────────

  /// Saves multiple conversations into local Isar DB (e.g. cloud sync on login).
  Future<void> saveBatch(List<Conversation> newConversations) async {
    if (newConversations.isEmpty) return;

    if (IsarService.isInitialized) {
      AppLogger.info('Isar',
          '[ConversationRepository] Transaction write: batch saving ${newConversations.length} conversations');
      await IsarService.isar.writeTxn(() async {
        for (final c in newConversations) {
          final existing = await IsarService.isar.conversationIsarModels
              .where()
              .conversationIdEqualTo(c.id)
              .findFirst();
          final model = c.toIsar();
          if (existing != null) {
            model.id = existing.id;
          }
          await IsarService.isar.conversationIsarModels.put(model);
        }
      });
      AppLogger.debug('Isar',
          '[ConversationRepository] Batch saved ${newConversations.length} conversations to Isar DB.');
      await _loadFromIsar();
    } else {
      for (final c in newConversations) {
        final index =
            _conversations.indexWhere((existing) => existing.id == c.id);
        if (index >= 0) {
          _conversations[index] = c;
        } else {
          _conversations.insert(0, c);
        }
      }
      AppLogger.debug('Isar',
          '[ConversationRepository] Batch saved ${newConversations.length} conversations to in-memory store.');
    }
    notifyListeners();
  }

  Future<void> _loadFromIsar() async {
    try {
      final all =
          await IsarService.isar.conversationIsarModels.where().findAll();
      AppLogger.debug('Isar',
          '[ConversationRepository] Query result: fetched ${all.length} total conversation records from Isar DB.');
      // Filter active (non-deleted), sort by updatedAt descending in Dart
      final active = all.where((m) => m.deletedAt == null).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      AppLogger.debug('Isar',
          '[ConversationRepository] Query result: ${active.length} active (non-deleted) conversations.');
      _conversations = active.map((m) => m.toDomain()).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Isar', '[ConversationRepository] Load error', e, stackTrace);
      _conversations = [];
    }
  }

  /// Finds a conversation by [id], applies [mutator], persists, and reloads.
  Future<void> _mutateConversation(
    String id,
    void Function(ConversationIsarModel model) mutator,
  ) async {
    if (IsarService.isInitialized) {
      AppLogger.info('Isar',
          '[ConversationRepository] Transaction write: mutating conversation $id');
      await IsarService.isar.writeTxn(() async {
        final existing = await IsarService.isar.conversationIsarModels
            .where()
            .conversationIdEqualTo(id)
            .findFirst();
        if (existing != null) {
          mutator(existing);
          await IsarService.isar.conversationIsarModels.put(existing);
          AppLogger.debug('Isar',
              '[ConversationRepository] Saved mutated conversation $id to Isar DB.');
        } else {
          AppLogger.warning('Isar',
              '[ConversationRepository] Conversation $id not found in Isar DB for mutation.');
        }
      });
      await _loadFromIsar();
    } else {
      final index = _conversations.indexWhere((c) => c.id == id);
      if (index >= 0) {
        final model = _conversations[index].toIsar();
        mutator(model);
        _conversations[index] = model.toDomain();
        AppLogger.debug('Isar',
            '[ConversationRepository] Saved mutated conversation $id in in-memory store.');
      } else {
        AppLogger.warning('Isar',
            '[ConversationRepository] Conversation $id not found in in-memory store for mutation.');
      }
    }
    notifyListeners();
  }
}

// lib/data/models/chat_message_isar.dart
//
// Isar collection model for AI chat messages — mirrors the Supabase
// `chat_messages` table 1-to-1.
//
// Column alignment:
//   chat_messages.id              → messageId       (@Index unique+replace)
//   chat_messages.conversation_id → conversationId  (@Index value — fast history fetch)
//   chat_messages.sender          → sender          ('user' | 'assistant')
//   chat_messages.content         → content
//   chat_messages.created_at      → createdAt       (@Index DateTime)
//
// `chat_messages` has no `deleted_at` column in Supabase (hard-deleted via
// CASCADE when the parent conversation is deleted), so none is added here.

import 'package:isar/isar.dart';
import '../../services/api/api_models.dart';
import '../../services/crypto_service.dart';

part 'chat_message_isar.g.dart';

@collection
class ChatMessageIsarModel {
  Id id = Isar.autoIncrement;

  /// Unique backend UUID index with replace semantics.
  @Index(unique: true, replace: true)
  late String messageId;

  /// Parent conversation UUID — indexed for fast per-conversation history queries.
  @Index(type: IndexType.value)
  late String conversationId;

  /// Sender role: 'user' | 'assistant' (mirrors Supabase CHECK constraint).
  late String sender;

  late String content;

  /// Native DateTime index for chronological message ordering.
  @Index()
  DateTime createdAt = DateTime.now();

  ChatMessageIsarModel();

  /// Construct from a backend DTO (ISO-8601 string converted to DateTime).
  factory ChatMessageIsarModel.fromDto(ChatMessageDto dto) {
    return ChatMessageIsarModel()
      ..messageId = dto.id
      ..conversationId = dto.conversationId
      ..sender = dto.sender
      ..content = dto.content
      ..createdAt =
          DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now();
  }

  /// Convert back to a network DTO for optimistic UI state.
  ChatMessageDto toDto() {
    return ChatMessageDto(
      id: messageId,
      conversationId: conversationId,
      sender: sender,
      content: content,
      createdAt: createdAt.toUtc().toIso8601String(),
    );
  }

  /// Encrypts content in-place using AES-256-GCM envelope encryption.
  Future<void> encryptSensitiveFields([CryptoService? crypto]) async {
    if (content.isNotEmpty && !content.startsWith('enc:v1:')) {
      content = await (crypto ?? CryptoService.instance).encryptText(content);
    }
  }

  /// Decrypts content in-place if it contains an AES-256-GCM envelope.
  Future<void> decryptSensitiveFields([CryptoService? crypto]) async {
    if (content.startsWith('enc:v1:')) {
      content = await (crypto ?? CryptoService.instance).decryptText(content);
    }
  }
}

// ── SAFE QUERY EXTENSIONS ────────────────────────────────────────────────────

extension ChatMessageIsarQueryFilters on QueryBuilder<ChatMessageIsarModel,
    ChatMessageIsarModel, QFilterCondition> {
  /// Filter messages belonging to a specific conversation UUID.
  QueryBuilder<ChatMessageIsarModel, ChatMessageIsarModel,
      QAfterFilterCondition> byConversation(
          String convId) =>
      conversationIdEqualTo(convId);
}

// lib/data/models/conversation_isar.dart
//
// Isar collection model for chat conversations — mirrors the Supabase
// `conversations` table 1-to-1.
//
// Column alignment:
//   conversations.id          → conversationId  (@Index unique+replace)
//   conversations.title       → title
//   conversations.created_at  → createdAt       (@Index DateTime)
//   conversations.updated_at  → updatedAt       (@Index DateTime)
//   conversations.deleted_at  → deletedAt       (@Index DateTime? — null = active)
//
// Supabase-only relational columns `user_id` and `device_id` are intentionally
// omitted: Isar stores data locally on-device, making these redundant.

import 'package:isar/isar.dart';
import '../../services/api/api_models.dart';

part 'conversation_isar.g.dart';

@collection
class ConversationIsarModel {
  Id id = Isar.autoIncrement;

  /// Unique backend UUID index with replace semantics:
  /// upserting the same conversationId silently overwrites the existing record.
  @Index(unique: true, replace: true)
  late String conversationId;

  late String title;

  /// Native DateTime index for sorting conversations by creation time.
  @Index()
  DateTime createdAt = DateTime.now();

  /// Native DateTime index — updated on every message sent.
  @Index()
  DateTime updatedAt = DateTime.now();

  /// Soft-delete timestamp — null means the conversation is active.
  @Index()
  DateTime? deletedAt;

  ConversationIsarModel();

  /// Construct from a backend DTO (ISO-8601 strings converted to DateTime).
  factory ConversationIsarModel.fromDto(ConversationDto dto) {
    return ConversationIsarModel()
      ..conversationId = dto.id
      ..title = dto.title
      ..createdAt =
          DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now()
      ..updatedAt =
          DateTime.tryParse(dto.updatedAt)?.toLocal() ?? DateTime.now();
  }

  /// Convert back to a network DTO for API calls.
  ConversationDto toDto({String deviceId = ''}) {
    return ConversationDto(
      id: conversationId,
      title: title,
      createdAt: createdAt.toUtc().toIso8601String(),
      updatedAt: updatedAt.toUtc().toIso8601String(),
      deviceId: deviceId,
    );
  }
}

// ── SAFE QUERY EXTENSIONS ────────────────────────────────────────────────────

extension ConversationIsarQueryFilters on QueryBuilder<ConversationIsarModel,
    ConversationIsarModel, QFilterCondition> {
  /// Filter active (non-deleted) conversations only.
  QueryBuilder<ConversationIsarModel, ConversationIsarModel,
      QAfterFilterCondition> activeOnly() => deletedAtIsNull();
}

// lib/domain/models/conversation.dart
//
// Immutable domain model representing a chat conversation.
// This is the clean business-layer object used by ViewModels and
// UI screens — it carries no Isar annotations or DTO-specific types.

import 'package:flutter/foundation.dart';
import '../../data/models/conversation_isar.dart';
import '../../services/api/api_models.dart';

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete timestamp — null means the conversation is active.
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;

  // ── COPY HELPER ──────────────────────────────────────────────────────────────

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  // ── ISAR CONVERTERS ──────────────────────────────────────────────────────────

  factory Conversation.fromIsar(ConversationIsarModel model) {
    return Conversation(
      id: model.conversationId,
      title: model.title,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      deletedAt: model.deletedAt,
    );
  }

  ConversationIsarModel toIsar() {
    return ConversationIsarModel()
      ..conversationId = id
      ..title = title
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..deletedAt = deletedAt;
  }

  // ── DTO CONVERTERS ───────────────────────────────────────────────────────────

  factory Conversation.fromDto(ConversationDto dto) {
    return Conversation(
      id: dto.id,
      title: dto.title,
      createdAt: DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(dto.updatedAt)?.toLocal() ?? DateTime.now(),
    );
  }

  ConversationDto toDto({String deviceId = ''}) {
    return ConversationDto(
      id: id,
      title: title,
      createdAt: createdAt.toUtc().toIso8601String(),
      updatedAt: updatedAt.toUtc().toIso8601String(),
      deviceId: deviceId,
    );
  }

  // ── EQUALITY ─────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ updatedAt.hashCode;

  @override
  String toString() =>
      'Conversation(id: $id, title: $title, updatedAt: $updatedAt)';
}

// lib/domain/models/chat_message.dart
//
// Immutable domain model representing a single AI chat message.
// Used by ViewModels and UI screens — carries no Isar annotations.

import 'package:flutter/foundation.dart';
import '../../data/models/chat_message_isar.dart';
import '../../services/api/api_models.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String conversationId;

  /// Sender role: 'user' | 'assistant'
  final String sender;

  final String content;
  final DateTime createdAt;

  bool get isUser => sender == 'user';
  bool get isAssistant => sender == 'assistant';

  // ── COPY HELPER ──────────────────────────────────────────────────────────────

  ChatMessage copyWith({String? content}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      sender: sender,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }

  // ── ISAR CONVERTERS ──────────────────────────────────────────────────────────

  factory ChatMessage.fromIsar(ChatMessageIsarModel model) {
    return ChatMessage(
      id: model.messageId,
      conversationId: model.conversationId,
      sender: model.sender,
      content: model.content,
      createdAt: model.createdAt,
    );
  }

  ChatMessageIsarModel toIsar() {
    return ChatMessageIsarModel()
      ..messageId = id
      ..conversationId = conversationId
      ..sender = sender
      ..content = content
      ..createdAt = createdAt;
  }

  // ── DTO CONVERTERS ───────────────────────────────────────────────────────────

  factory ChatMessage.fromDto(ChatMessageDto dto) {
    return ChatMessage(
      id: dto.id,
      conversationId: dto.conversationId,
      sender: dto.sender,
      content: dto.content,
      createdAt: DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now(),
    );
  }

  ChatMessageDto toDto() {
    return ChatMessageDto(
      id: id,
      conversationId: conversationId,
      sender: sender,
      content: content,
      createdAt: createdAt.toUtc().toIso8601String(),
    );
  }

  // ── EQUALITY ─────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId;

  @override
  int get hashCode => id.hashCode ^ conversationId.hashCode;

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $sender, conversationId: $conversationId)';
}

// lib/data/mappers/chat_message_mapper.dart
//
// Data Mappers for ChatMessage entities.
// Keeps the domain model (ChatMessage) 100% decoupled from Isar DB annotations
// and API network DTOs, enforcing UTC timestamp normalization.

import '../../domain/models/chat_message.dart';
import '../models/chat_message_isar.dart';
import '../../services/api/api_models.dart';

extension ChatMessageIsarMapper on ChatMessageIsarModel {
  ChatMessage toDomain() {
    return ChatMessage(
      id: messageId,
      conversationId: conversationId,
      sender: sender,
      content: content,
      createdAt: createdAt.toUtc(),
    );
  }
}

extension ChatMessageDomainMapper on ChatMessage {
  ChatMessageIsarModel toIsar() {
    return ChatMessageIsarModel()
      ..messageId = id
      ..conversationId = conversationId
      ..sender = sender
      ..content = content
      ..createdAt = createdAt.toUtc();
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
}

extension ChatMessageDtoMapper on ChatMessageDto {
  ChatMessage toDomain() {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      sender: sender,
      content: content,
      createdAt:
          DateTime.tryParse(createdAt)?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

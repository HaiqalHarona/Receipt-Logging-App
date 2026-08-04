// lib/data/mappers/conversation_mapper.dart
//
// Data Mappers for Conversation entities.
// Keeps the domain model (Conversation) 100% decoupled from Isar DB annotations
// and API network DTOs.

import '../../domain/models/conversation.dart';
import '../models/conversation_isar.dart';
import '../../services/api/api_models.dart';

extension ConversationIsarMapper on ConversationIsarModel {
  Conversation toDomain() {
    return Conversation(
      id: conversationId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}

extension ConversationDomainMapper on Conversation {
  ConversationIsarModel toIsar() {
    return ConversationIsarModel()
      ..conversationId = id
      ..title = title
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      ..deletedAt = deletedAt;
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
}

extension ConversationDtoMapper on ConversationDto {
  Conversation toDomain() {
    return Conversation(
      id: id,
      title: title,
      createdAt: DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAt)?.toLocal() ?? DateTime.now(),
    );
  }
}

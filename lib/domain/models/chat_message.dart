// lib/domain/models/chat_message.dart
//
// Pure immutable domain model representing a single AI chat message.
// Carries zero database or network dependencies.

import 'package:flutter/foundation.dart';

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

  // ── EQUALITY ─────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          sender == other.sender &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      conversationId.hashCode ^
      sender.hashCode ^
      content.hashCode ^
      createdAt.hashCode;

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $sender, conversationId: $conversationId)';
}

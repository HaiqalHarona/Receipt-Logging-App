/// Dart DTO models for Chat endpoints.
///
/// Covers:
///   POST   /api/v1/chat/create   → [ConversationDto]
///   GET    /api/v1/chat/list     → List<[ConversationDto]>
///   POST   /api/v1/chat/query    → [ChatQueryResponseDto]
///   GET    /api/v1/chat/history  → List<[ChatMessageDto]>
///   DELETE /api/v1/chat/{id}     → bool
library;

// ── CHAT MESSAGE ──────────────────────────────────────────────────────────────

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String sender; // "user" | "assistant"
  final String content;
  final String createdAt;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: (json['id'] as String?) ?? '',
      conversationId: (json['conversation_id'] as String?) ?? '',
      sender: (json['sender'] as String?) ?? 'user',
      content: (json['content'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

// ── CHAT QUERY RESPONSE ───────────────────────────────────────────────────────

class ChatQueryResponseDto {
  const ChatQueryResponseDto({
    required this.conversationId,
    required this.userMessage,
    required this.assistantMessage,
  });

  final String conversationId;
  final ChatMessageDto userMessage;
  final ChatMessageDto assistantMessage;

  factory ChatQueryResponseDto.fromJson(Map<String, dynamic> json) {
    return ChatQueryResponseDto(
      conversationId: (json['conversation_id'] as String?) ?? '',
      userMessage:
          ChatMessageDto.fromJson(json['user_message'] as Map<String, dynamic>),
      assistantMessage: ChatMessageDto.fromJson(
          json['assistant_message'] as Map<String, dynamic>),
    );
  }
}

// ── CONVERSATION ──────────────────────────────────────────────────────────────

class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    required this.deviceId,
  });

  final String id;
  final String? userId;
  final String deviceId;
  final String title;
  final String createdAt;
  final String updatedAt;

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      id: (json['id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      deviceId: (json['device_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'New Conversation',
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
}

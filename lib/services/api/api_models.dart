/// Dart DTO models that mirror the FastAPI Pydantic schemas in the backend.
///
/// These are used exclusively by [BackendApiClient] to serialize request bodies
/// and deserialize response JSON. They are intentionally thin — no business
/// logic, just JSON mapping.
library;

// ── LINE ITEM ──────────────────────────────────────────────────────────────────

class LineItemDto {
  const LineItemDto({
    required this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  final String description;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;

  factory LineItemDto.fromJson(Map<String, dynamic> json) {
    return LineItemDto(
      description: (json['description'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      totalPrice: (json['total_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (totalPrice != null) 'total_price': totalPrice,
      };
}

// ── RECEIPT ────────────────────────────────────────────────────────────────────

class ReceiptDto {
  const ReceiptDto({
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.rawText,
    this.lineItems = const [],
    this.subtotal,
    this.taxAmount,
    this.currency = 'USD',
    this.category,
    this.confidenceScore = 0.0,
    this.notes,
  });

  final String merchantName;
  final List<LineItemDto> lineItems;
  final double? subtotal;
  final double? taxAmount;
  final double totalAmount;
  final String currency;
  final String? category;
  final String date;          // ISO 8601 string
  final String rawText;
  final double confidenceScore;
  final String? notes;

  factory ReceiptDto.fromJson(Map<String, dynamic> json) {
    return ReceiptDto(
      merchantName: (json['merchant_name'] as String?) ?? 'Unknown Merchant',
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((e) => LineItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] as String?) ?? 'USD',
      category: json['category'] as String?,
      date: (json['date'] as String?) ?? DateTime.now().toIso8601String(),
      rawText: (json['raw_text'] as String?) ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_name': merchantName,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
        if (subtotal != null) 'subtotal': subtotal,
        if (taxAmount != null) 'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'currency': currency,
        if (category != null) 'category': category,
        'date': date,
        'raw_text': rawText,
        'confidence_score': confidenceScore,
        if (notes != null) 'notes': notes,
      };
}

// ── SCAN RESPONSE ─────────────────────────────────────────────────────────────

class ScanResponseDto {
  const ScanResponseDto({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final ReceiptDto? data;
  final String? error;

  factory ScanResponseDto.fromJson(Map<String, dynamic> json) {
    return ScanResponseDto(
      success: (json['success'] as bool?) ?? false,
      data: json['data'] != null
          ? ReceiptDto.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}

// ── RECEIPT RECORD ────────────────────────────────────────────────────────────

class ReceiptRecordDto {
  const ReceiptRecordDto({
    required this.id,
    required this.deviceId,
    required this.receipt,
    required this.createdAt,
    this.userId,
    this.deletedAt,
  });

  final String id;
  final String? userId;
  final String deviceId;
  final ReceiptDto receipt;
  final String createdAt;
  final String? deletedAt;

  factory ReceiptRecordDto.fromJson(Map<String, dynamic> json) {
    return ReceiptRecordDto(
      id: (json['id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      deviceId: (json['device_id'] as String?) ?? '',
      receipt: ReceiptDto.fromJson(json['receipt'] as Map<String, dynamic>),
      createdAt: (json['created_at'] as String?) ?? '',
      deletedAt: json['deleted_at'] as String?,
    );
  }
}

// ── DEVICE ────────────────────────────────────────────────────────────────────

class DeviceRecordDto {
  const DeviceRecordDto({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final String? userId;
  final String createdAt;

  factory DeviceRecordDto.fromJson(Map<String, dynamic> json) {
    return DeviceRecordDto(
      id: (json['id'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

// ── CHAT ──────────────────────────────────────────────────────────────────────

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
      userMessage: ChatMessageDto.fromJson(
          json['user_message'] as Map<String, dynamic>),
      assistantMessage: ChatMessageDto.fromJson(
          json['assistant_message'] as Map<String, dynamic>),
    );
  }
}

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

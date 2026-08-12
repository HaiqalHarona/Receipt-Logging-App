// lib/services/data_export_service.dart
//
// Exports all guest local Isar DB records (receipts, conversations, chat_messages)
// into a single JSON-serializable map for submission to POST /api/v1/devices/link
// as `migrate_data` during sign-up.

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../data/repositories/receipt_repository.dart';
import '../data/repositories/conversation_repository.dart';
import '../services/isar_service.dart';
import '../data/models/chat_message_isar.dart';

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  /// Exports all non-deleted guest data into a map matching the backend's
  /// `DeviceLinkRequest.migrate_data` schema:
  /// ```json
  /// {
  ///   "receipts": [ { "id": "...", "receipt": {...}, "created_at": "..." }, ... ],
  ///   "conversations": [ { "id": "...", "title": "...", "created_at": "...", "updated_at": "..." }, ... ],
  ///   "chat_messages": [ { "id": "...", "conversation_id": "...", "sender": "...", "content": "...", "created_at": "..." }, ... ]
  /// }
  /// ```
  Future<Map<String, dynamic>> exportGuestData() async {
    try {
      await ReceiptRepository.instance.init();
      await ConversationRepository.instance.init();

      final receipts = ReceiptRepository.instance.receipts;
      final conversations = ConversationRepository.instance.conversations;

      // ── Receipts ────────────────────────────────────────────────────────────
      final receiptsJson = receipts.map((r) => {
        'id': r.id,
        'receipt': {
          'merchant_name': r.merchant,
          'line_items': r.lineItems.map((l) => l.toJson()).toList(),
          'total_amount': r.amount,
          'currency': r.currency,
          'category': r.category,
          'date': r.date,
          'raw_text': '',
          'confidence_score': 0.0,
        },
        'created_at': r.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      }).toList();

      // ── Conversations ────────────────────────────────────────────────────────
      final conversationsJson = conversations.map((c) => {
        'id': c.id,
        'title': c.title,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
      }).toList();

      // ── Chat Messages (all conversations from Isar directly) ─────────────────
      final List<Map<String, dynamic>> chatMessagesJson = [];
      if (IsarService.isInitialized && conversationsJson.isNotEmpty) {
        for (final conv in conversations) {
          final msgs = await IsarService.isar.chatMessageIsarModels
              .where()
              .conversationIdEqualTo(conv.id)
              .findAll();
          for (final m in msgs) {
            chatMessagesJson.add({
              'id': m.messageId,
              'conversation_id': m.conversationId,
              'sender': m.sender,
              'content': m.content,
              'created_at': m.createdAt.toIso8601String(),
            });
          }
        }
      }

      final result = {
        'receipts': receiptsJson,
        'conversations': conversationsJson,
        'chat_messages': chatMessagesJson,
      };

      debugPrint(
        '📦 [DataExportService] Exported guest data: '
        'receipts=${receiptsJson.length} '
        'conversations=${conversationsJson.length} '
        'chat_messages=${chatMessagesJson.length}',
      );
      return result;
    } catch (e) {
      debugPrint('⚠️ [DataExportService] Export failed: $e');
      return {'receipts': [], 'conversations': [], 'chat_messages': []};
    }
  }
}

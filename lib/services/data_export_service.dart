// lib/services/data_export_service.dart
//
// Exports all guest local Isar DB records (receipts, conversations, chat_messages)
// into a single JSON-serializable map for submission to POST /api/v1/devices/link
// as `migrate_data` during sign-up.

import 'package:isar/isar.dart';
import 'app_logger_service.dart';
import 'category_service.dart';
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

      // Filter to export ONLY local guest data (records with local IDs like res-xxx),
      // skipping records that were downloaded from Supabase (valid 36-char UUIDs).
      final guestReceipts = receipts.where((r) => !_isUuid(r.id)).toList();
      final guestConversations =
          conversations.where((c) => !_isUuid(c.id)).toList();

      // ── Receipts ────────────────────────────────────────────────────────────
      final receiptsJson = guestReceipts
          .map((r) => {
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
                'created_at':
                    (r.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
              })
          .toList();

      // ── Conversations ────────────────────────────────────────────────────────
      final conversationsJson = guestConversations
          .map((c) => {
                'id': c.id,
                'title': c.title,
                'created_at': c.createdAt.toUtc().toIso8601String(),
                'updated_at': c.updatedAt.toUtc().toIso8601String(),
              })
          .toList();

      // ── Chat Messages (all conversations from Isar directly) ─────────────────
      final List<Map<String, dynamic>> chatMessagesJson = [];
      if (IsarService.isInitialized && conversationsJson.isNotEmpty) {
        for (final conv in guestConversations) {
          final msgs = await IsarService.isar.chatMessageIsarModels
              .where()
              .conversationIdEqualTo(conv.id)
              .findAll();
          for (final m in msgs) {
            if (!_isUuid(m.messageId)) {
              chatMessagesJson.add({
                'id': m.messageId,
                'conversation_id': m.conversationId,
                'sender': m.sender,
                'content': m.content,
                'created_at': m.createdAt.toUtc().toIso8601String(),
              });
            }
          }
        }
      }

      // ── Custom Categories ───────────────────────────────────────────────────
      await CategoryService.instance.init();
      final customCategories = CategoryService.instance.customCategories;
      final customCategoriesJson =
          customCategories.map((c) => c.toJson()).toList();

      final result = {
        'receipts': receiptsJson,
        'conversations': conversationsJson,
        'chat_messages': chatMessagesJson,
        'custom_categories': customCategoriesJson,
      };

      AppLogger.info(
        'DataExport',
        'Exported guest data: '
            'receipts=${receiptsJson.length} '
            'conversations=${conversationsJson.length} '
            'chat_messages=${chatMessagesJson.length} '
            'custom_categories=${customCategoriesJson.length}',
      );
      return result;
    } catch (e, st) {
      AppLogger.error('DataExport', 'Export failed', e, st);
      return {
        'receipts': [],
        'conversations': [],
        'chat_messages': [],
        'custom_categories': []
      };
    }
  }

  bool _isUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }
}

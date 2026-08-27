// lib/services/data_export_service.dart
//
// Exports all guest local Isar DB records (receipts, conversations, chat_messages)
// into a single JSON-serializable map for submission to POST /api/v1/devices/link
// as `migrate_data` during sign-up.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import 'app_logger_service.dart';
import 'category_service.dart';
import '../cloud/api/api_config.dart';
import '../data/repositories/receipt_repository.dart';
import '../data/repositories/conversation_repository.dart';
import '../services/isar_service.dart';
import '../data/models/chat_message_isar.dart';

enum ExportFormat { json, csv }

class DataExportResult {
  final bool success;
  final String? filePath;
  final int receiptsCount;
  final int conversationsCount;
  final int messagesCount;
  final String? errorMessage;

  const DataExportResult({
    required this.success,
    this.filePath,
    this.receiptsCount = 0,
    this.conversationsCount = 0,
    this.messagesCount = 0,
    this.errorMessage,
  });
}

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  /// Exports all non-deleted guest data into a map matching the backend's
  /// `DeviceLinkRequest.migrate_data` schema:
  /// ```json
  /// {
  ///   "receipts": [ { "id": "...", "receipt": {...}, "created_at": "...", "image_base64": "..." }, ... ],
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
      final List<Map<String, dynamic>> receiptsJson = [];
      for (final r in guestReceipts) {
        String? imageBase64;
        String? imageFilename;
        if (r.imagePath != null && r.imagePath!.isNotEmpty) {
          try {
            final file = File(r.imagePath!);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              if (bytes.length <= 10 * 1024 * 1024) {
                imageBase64 = base64Encode(bytes);
                imageFilename = r.imagePath!.split(Platform.pathSeparator).last;
                AppLogger.debug('DataExport',
                    'Exporting guest receipt image (${bytes.length} bytes) for receipt ${r.id}');
              } else {
                AppLogger.warning('DataExport',
                    'Guest receipt image exceeds 10MB limit, omitting image for ${r.id}');
              }
            }
          } catch (e) {
            AppLogger.warning('DataExport',
                'Could not read guest receipt image at ${r.imagePath}: $e');
          }
        }

        receiptsJson.add({
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
          if (imageBase64 != null) 'image_base64': imageBase64,
          if (imageFilename != null) 'image_filename': imageFilename,
        });
      }

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
      if (IsarService.isInitialized && guestConversations.isNotEmpty) {
        for (final conv in guestConversations) {
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
              'created_at': m.createdAt.toUtc().toIso8601String(),
            });
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

  /// Exports ALL local Isar database records (both guest and cloud-synced) to
  /// a local file on the device in either JSON or CSV format.
  /// Zero network/cloud requests — purely reads from local Isar database.
  Future<DataExportResult> exportToFile({
    ExportFormat format = ExportFormat.json,
    Directory? targetDirectory,
  }) async {
    try {
      await ReceiptRepository.instance.init();
      await ConversationRepository.instance.init();
      try {
        await CategoryService.instance.init();
      } catch (_) {}

      final receipts = ReceiptRepository.instance.receipts;
      final conversations = ConversationRepository.instance.conversations;

      // ── 1. Receipts & Line Items ───────────────────────────────────────────
      final List<Map<String, dynamic>> receiptsJson = receipts.map((r) {
        return {
          'id': r.id,
          'merchant': r.merchant,
          'amount': r.amount,
          'currency': r.currency,
          'category': r.category,
          'date': r.date,
          'line_items': r.lineItems.map((l) => l.toJson()).toList(),
          'created_at':
              (r.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        };
      }).toList();

      // ── 2. Conversations ───────────────────────────────────────────────────
      final List<Map<String, dynamic>> conversationsJson =
          conversations.map((c) {
        return {
          'id': c.id,
          'title': c.title,
          'created_at': c.createdAt.toUtc().toIso8601String(),
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
        };
      }).toList();

      // ── 3. Chat Messages (from Isar) ────────────────────────────────────────
      final List<Map<String, dynamic>> chatMessagesJson = [];
      if (IsarService.isInitialized && conversations.isNotEmpty) {
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
              'created_at': m.createdAt.toUtc().toIso8601String(),
            });
          }
        }
      }

      // ── 4. Custom Categories ───────────────────────────────────────────────
      final customCategories = CategoryService.instance.customCategories;
      final customCategoriesJson =
          customCategories.map((c) => c.toJson()).toList();

      // ── 5. File Content Generation ─────────────────────────────────────────
      final String fileContent;
      final String fileExt;

      if (format == ExportFormat.json) {
        fileExt = 'json';
        final Map<String, dynamic> exportPayload = {
          'export_version': '1.0',
          'exported_at': DateTime.now().toUtc().toIso8601String(),
          'app_version': ApiConfig.appVersionDisplay,
          'summary': {
            'receipts_count': receiptsJson.length,
            'conversations_count': conversationsJson.length,
            'chat_messages_count': chatMessagesJson.length,
            'custom_categories_count': customCategoriesJson.length,
          },
          'receipts': receiptsJson,
          'conversations': conversationsJson,
          'chat_messages': chatMessagesJson,
          'custom_categories': customCategoriesJson,
        };
        fileContent = const JsonEncoder.withIndent('  ').convert(exportPayload);
      } else {
        fileExt = 'csv';
        final StringBuffer buffer = StringBuffer();
        // RFC 4180 Unified Header
        buffer.writeln(
            'Record_Type,ID,Reference_ID,Name_or_Sender,Category,Amount,Currency,Date_or_Timestamp,Details_or_Content');

        // Receipts
        for (final r in receipts) {
          final lineItemsSummary = r.lineItems
              .map((l) =>
                  '${l.description} (${l.quantity ?? 1}x @ ${l.effectiveUnitPrice})')
              .join('; ');
          buffer.writeln([
            _csvEscape('RECEIPT'),
            _csvEscape(r.id),
            _csvEscape(''),
            _csvEscape(r.merchant),
            _csvEscape(r.category),
            _csvEscape(r.amount.toStringAsFixed(2)),
            _csvEscape(r.currency),
            _csvEscape(r.date),
            _csvEscape(lineItemsSummary),
          ].join(','));
        }

        // Line Items
        for (final r in receipts) {
          for (final l in r.lineItems) {
            buffer.writeln([
              _csvEscape('LINE_ITEM'),
              _csvEscape(''),
              _csvEscape(r.id),
              _csvEscape(l.description),
              _csvEscape(r.category),
              _csvEscape(l.lineTotal.toStringAsFixed(2)),
              _csvEscape(r.currency),
              _csvEscape(r.date),
              _csvEscape(
                  'Qty: ${l.quantity ?? 1}, Unit Price: ${l.effectiveUnitPrice}'),
            ].join(','));
          }
        }

        // Conversations
        for (final c in conversations) {
          buffer.writeln([
            _csvEscape('CONVERSATION'),
            _csvEscape(c.id),
            _csvEscape(''),
            _csvEscape(c.title),
            _csvEscape('AI_Chat'),
            _csvEscape(''),
            _csvEscape(''),
            _csvEscape(c.createdAt.toUtc().toIso8601String()),
            _csvEscape('Updated: ${c.updatedAt.toUtc().toIso8601String()}'),
          ].join(','));
        }

        // Chat Messages
        for (final m in chatMessagesJson) {
          buffer.writeln([
            _csvEscape('CHAT_MESSAGE'),
            _csvEscape(m['id']),
            _csvEscape(m['conversation_id']),
            _csvEscape(m['sender']),
            _csvEscape('ChatMessage'),
            _csvEscape(''),
            _csvEscape(''),
            _csvEscape(m['created_at']),
            _csvEscape(m['content']),
          ].join(','));
        }

        // Custom Categories
        for (final cat in customCategories) {
          buffer.writeln([
            _csvEscape('CATEGORY'),
            _csvEscape(cat.name),
            _csvEscape(''),
            _csvEscape(cat.name),
            _csvEscape('Category'),
            _csvEscape(''),
            _csvEscape(''),
            _csvEscape(''),
            _csvEscape(
                'IconCode: ${cat.iconCodePoint}, ColorValue: ${cat.colorValue}'),
          ].join(','));
        }

        fileContent = buffer.toString();
      }

      // ── 6. Write File to Storage ───────────────────────────────────────────
      final timestamp = DateTime.now()
          .toLocal()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final fileName = 'sancfund_export_$timestamp.$fileExt';

      Directory? targetDir = targetDirectory;
      if (targetDir == null) {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            targetDir = await getDownloadsDirectory();
          } catch (_) {}
        }

        if (targetDir == null || !await targetDir.exists()) {
          try {
            targetDir = await getApplicationDocumentsDirectory();
          } catch (_) {
            try {
              targetDir = await getTemporaryDirectory();
            } catch (_) {
              targetDir = Directory.systemTemp;
            }
          }
        }
      }
      targetDir = Directory.systemTemp;

      final file = File('${targetDir.path}/$fileName');
      await file.writeAsString(fileContent, flush: true);

      AppLogger.info('DataExport',
          'Local DB exported successfully to ${file.path} (${fileContent.length} bytes)');

      return DataExportResult(
        success: true,
        filePath: file.path,
        receiptsCount: receiptsJson.length,
        conversationsCount: conversationsJson.length,
        messagesCount: chatMessagesJson.length,
      );
    } catch (e, st) {
      AppLogger.error('DataExport', 'exportToFile failed', e, st);
      return DataExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  static String _csvEscape(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\n') ||
        str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }
}

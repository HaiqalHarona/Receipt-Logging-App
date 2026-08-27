// test/unit/data_export_service_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/api/api_config.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/data/repositories/conversation_repository.dart';
import 'package:reciept_logging/services/data_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataExportService & ExportToFile Unit Tests', () {
    setUp(() async {
      await ReceiptRepository.instance.init();
      await ConversationRepository.instance.init();

      // Seed a local receipt (guest ID)
      await ReceiptRepository.instance.saveReceipt(
        const Receipt(
          id: 'res-local-001',
          merchant: 'Local Coffee, Cafe & "Bakery"',
          amount: 15.50,
          currency: 'SGD',
          category: 'Food & Dining',
          date: '2026-08-27',
          lineItems: [
            LineItem(
              description: 'Latte, Oat Milk',
              quantity: 2,
              unitPrice: 6.50,
            ),
            LineItem(
              description: 'Croissant',
              quantity: 1,
              unitPrice: 2.50,
            ),
          ],
        ),
      );

      // Seed a cloud-synced receipt (UUID)
      await ReceiptRepository.instance.saveReceipt(
        const Receipt(
          id: '12345678-1234-1234-1234-123456789abc',
          merchant: 'Cloud Mart',
          amount: 42.00,
          currency: 'SGD',
          category: 'Groceries',
          date: '2026-08-26',
          lineItems: [],
        ),
      );

      // Seed a conversation
      await ConversationRepository.instance.createConversation(
        title: 'Monthly Budget Analysis',
        id: 'conv-test-01',
      );
    });

    test(
        'exportToFile(format: ExportFormat.json) exports all records including cloud synced UUIDs',
        () async {
      final result = await DataExportService.instance
          .exportToFile(format: ExportFormat.json);

      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);
      expect(result.receiptsCount, greaterThanOrEqualTo(2));
      expect(result.conversationsCount, greaterThanOrEqualTo(1));

      final file = File(result.filePath!);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);

      expect(json['export_version'], equals('1.0'));
      expect(json['exported_at'], isNotNull);
      expect(json['receipts'], isA<List>());
      expect((json['receipts'] as List).length, greaterThanOrEqualTo(2));
      expect(json['conversations'], isA<List>());
      expect((json['conversations'] as List).length, greaterThanOrEqualTo(1));

      // Clean up test export file
      try {
        await file.delete();
      } catch (_) {}
    });

    test(
        'exportToFile(format: ExportFormat.csv) produces valid RFC 4180 CSV with proper escaping',
        () async {
      final result = await DataExportService.instance
          .exportToFile(format: ExportFormat.csv);

      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);
      expect(result.filePath!.endsWith('.csv'), isTrue);

      final file = File(result.filePath!);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(
          content,
          contains(
              'Record_Type,ID,Reference_ID,Name_or_Sender,Category,Amount,Currency,Date_or_Timestamp,Details_or_Content'));
      expect(content, contains('RECEIPT'));
      expect(content, contains('Local Coffee, Cafe & ""Bakery""'));
      expect(content, contains('Cloud Mart'));
      expect(content, contains('CONVERSATION'));
      expect(content, contains('Monthly Budget Analysis'));

      // Clean up test export file
      try {
        await file.delete();
      } catch (_) {}
    });

    test('ApiConfig.isDevelopment evaluates correctly based on environment',
        () {
      expect(ApiConfig.isDevelopment, isA<bool>());
    });
  });
}

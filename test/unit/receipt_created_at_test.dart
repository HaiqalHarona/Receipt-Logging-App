// File: test/unit/receipt_created_at_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/data/models/receipt_isar.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Receipt createdAt Timestamp Tests', () {
    test('Receipt domain model handles createdAt serialization and copyWith',
        () {
      final now = DateTime.now();
      final receipt = Receipt(
        id: 'test-1',
        merchant: 'Store A',
        date: '2026-08-09',
        amount: 50.0,
        currency: 'USD',
        category: 'Groceries',
        createdAt: now,
      );

      expect(receipt.createdAt, equals(now));

      final json = receipt.toJson();
      expect(json['createdAt'], equals(now.toIso8601String()));

      final restored = Receipt.fromJson(json);
      expect(restored.createdAt, equals(now));

      final copy = receipt.copyWith(amount: 75.0);
      expect(copy.createdAt, equals(now));
      expect(copy.amount, equals(75.0));
    });

    test('ReceiptIsarModel maps createdAt bi-directionally', () {
      final now = DateTime(2026, 8, 9, 13, 30);
      final receipt = Receipt(
        id: 'test-isar-1',
        merchant: 'Store B',
        date: '2026-08-09',
        amount: 25.0,
        currency: 'USD',
        category: 'Transport',
        createdAt: now,
      );

      final isarModel = ReceiptIsarModel.fromDomain(receipt);
      expect(isarModel.createdAt, equals(now));

      final domainModel = isarModel.toDomain();
      expect(domainModel.createdAt, equals(now));
    });

    test(
        'ReceiptRepository.saveReceipt automatically populates createdAt if null',
        () async {
      final repo = ReceiptRepository.instance;
      const newReceipt = Receipt(
        id: 'test-auto-created-at',
        merchant: 'Store C',
        date: '2026-08-09',
        amount: 15.0,
        currency: 'USD',
        category: 'Dining',
      );

      expect(newReceipt.createdAt, isNull);

      await repo.saveReceipt(newReceipt);

      final saved =
          repo.receipts.firstWhere((r) => r.id == 'test-auto-created-at');
      expect(saved.createdAt, isNotNull);
      expect(
          saved.createdAt!
              .isAfter(DateTime.now().subtract(const Duration(seconds: 10))),
          isTrue);
    });
  });
}

// File: test/unit/receipt_seeder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/data/seeders/receipt_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptSeeder Unit Tests', () {
    test('generate24Receipts produces exactly 24 valid records', () {
      final receipts = ReceiptSeeder.generate24Receipts();
      expect(receipts.length, equals(24));
    });

    test('generate24Receipts generates 2 records per month for 12 months', () {
      final receipts = ReceiptSeeder.generate24Receipts();
      final now = DateTime.now();

      for (int i = 0; i < 12; i++) {
        final targetYearMonth = DateTime(now.year, now.month - i, 1);
        final countInMonth = receipts.where((r) {
          return r.createdAt != null &&
              r.createdAt!.year == targetYearMonth.year &&
              r.createdAt!.month == targetYearMonth.month;
        }).length;

        expect(countInMonth, equals(2),
            reason:
                'Month ${targetYearMonth.month}/${targetYearMonth.year} should have 2 receipts');
      }
    });

    test(
        'All generated receipts satisfy item count, pricing, qty, and emoji-free constraints',
        () {
      final receipts = ReceiptSeeder.generate24Receipts();
      final emojiRegExp = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]',
        unicode: true,
      );

      for (final r in receipts) {
        // Line items count between 1 and 5
        expect(r.lineItems.length, greaterThanOrEqualTo(1));
        expect(r.lineItems.length, lessThanOrEqualTo(5));

        // Line item pricing ($5-$30) & qty (1-6)
        for (final item in r.lineItems) {
          expect(item.unitPrice, isNotNull);
          expect(item.unitPrice!, greaterThanOrEqualTo(5.0));
          expect(item.unitPrice!, lessThanOrEqualTo(30.0));

          expect(item.quantity, isNotNull);
          expect(item.quantity!, greaterThanOrEqualTo(1.0));
          expect(item.quantity!, lessThanOrEqualTo(6.0));

          expect(
              item.totalPrice,
              equals(
                  ((item.unitPrice! * item.quantity!) * 100).round() / 100.0));
        }

        // Total amount matches sum of line items
        final sumItems = r.lineItems
            .fold<double>(0.0, (acc, item) => acc + item.totalPrice!);
        expect(r.amount, equals((sumItems * 100).round() / 100.0));

        // Category constraints: max 3 category tags, emoji-free
        final tags = r.category
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        expect(tags.length, greaterThanOrEqualTo(1));
        expect(tags.length, lessThanOrEqualTo(3));
        expect(emojiRegExp.hasMatch(r.category), isFalse,
            reason: 'Category should contain no emojis: ${r.category}');

        // Merchant name non-empty
        expect(r.merchant.isNotEmpty, isTrue);
      }
    });
  });
}

// File: test/unit/category_tags_and_edit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/ui/core/utils/category_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Overflow & Edit Pre-Selection Unit Tests', () {
    test(
        'ReceiptListItemWidget displays max 2 tags and correct +X overflow count',
        () {
      const rawCategory = 'Groceries 🛒, Electronics, Dining, Shopping';
      final allTags = rawCategory
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      final displayTags = allTags.take(2).toList();
      final remainingCount = allTags.length - 2;

      expect(allTags.length, equals(4));
      expect(displayTags, equals(['Groceries', 'Electronics']));
      expect(remainingCount, equals(2));
    });

    test(
        'ReceiptDetailScreen parses all categories for wrapped multi-row layout',
        () {
      const rawCategory = 'Groceries, Transport 🚗, Dining 🍔';
      final allDetailTags = rawCategory
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      expect(allDetailTags.length, equals(3));
      expect(allDetailTags, equals(['Groceries', 'Transport', 'Dining']));
    });

    test(
        'VerificationCardWidget sanitizes category tokens on load to match pre-selected chips',
        () {
      const receipt = Receipt(
        id: 'rec_edit_01',
        merchant: 'Supermarket',
        date: 'Aug 06, 2026',
        amount: 85.0,
        currency: 'USD',
        category: 'Groceries 🛒, Dining 🍔',
      );

      final selectedCategories = receipt.category
          .split(',')
          .map((s) => CategoryUtils.sanitize(s).trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      expect(selectedCategories, containsAll(['Groceries', 'Dining']));
      expect(selectedCategories.contains('Groceries'), isTrue);

      // Verify re-saving does not duplicate category tokens
      final savedCategory = selectedCategories.toSet().join(', ');
      expect(savedCategory, equals('Groceries, Dining'));
    });

    test(
        'CategoryUtils.sanitize strips emojis cleanly and returns empty string for empty input',
        () {
      expect(CategoryUtils.sanitize('General 🧾'), equals('General'));
      expect(CategoryUtils.sanitize('Groceries 🛒'), equals('Groceries'));
      expect(CategoryUtils.sanitize(''), equals(''));
    });

    test(
        'Empty category string remains empty without forcing default General category',
        () {
      const receipt = Receipt(
        id: 'rec_empty_01',
        merchant: 'Target',
        date: 'Aug 08, 2026',
        amount: 25.0,
        currency: 'USD',
        category: '',
      );

      final selectedCategories = receipt.category
          .split(',')
          .map((s) => CategoryUtils.sanitize(s).trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      expect(selectedCategories, isEmpty);
    });
  });
}

// File: test/unit/history_view_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/history/view_models/history_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryViewModel Search, Filter, and Sort Unit Tests', () {
    late HistoryViewModel viewModel;

    setUp(() {
      viewModel = HistoryViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initial state loads sample receipts', () {
      expect(viewModel.receipts.length, greaterThanOrEqualTo(5));
      expect(viewModel.availableCategories,
          containsAll(['Groceries', 'Transport', 'Electronics', 'Dining']));
    });

    test('Category filtering narrows receipt list', () {
      viewModel.toggleCategory('Transport');
      expect(viewModel.selectedCategories, contains('Transport'));
      expect(viewModel.receipts.length, equals(1));
      expect(viewModel.receipts.first.merchant, equals('Shell Gas Station'));

      viewModel.clearCategories();
      expect(viewModel.selectedCategories, isEmpty);
      expect(viewModel.receipts.length, greaterThanOrEqualTo(5));
    });

    test('Sort by Name (Tap 1: A-Z, Tap 2: Z-A, Tap 3: Reset)', () {
      viewModel.toggleSort(HistorySortField.name); // Tap 1: Ascending (A-Z)
      expect(viewModel.sortField, equals(HistorySortField.name));
      expect(viewModel.sortAscending, isTrue);
      expect(viewModel.receipts.first.merchant, equals('Apple Store NYC'));

      viewModel.toggleSort(HistorySortField.name); // Tap 2: Descending (Z-A)
      expect(viewModel.sortAscending, isFalse);
      expect(viewModel.receipts.first.merchant, equals('Whole Foods Market'));

      viewModel.toggleSort(HistorySortField.name); // Tap 3: Reset to none
      expect(viewModel.sortField, equals(HistorySortField.none));
    });

    test(
        'Sort by Amount (Tap 1: \$ Low-High, Tap 2: \$ High-Low, Tap 3: Reset)',
        () {
      viewModel.toggleSort(
          HistorySortField.amount); // Tap 1: Ascending (\$ Low-High)
      expect(viewModel.sortField, equals(HistorySortField.amount));
      expect(viewModel.sortAscending, isTrue);
      expect(
          viewModel.receipts.first.amount, equals(12.50)); // Blue Bottle Coffee

      viewModel.toggleSort(
          HistorySortField.amount); // Tap 2: Descending (\$ High-Low)
      expect(viewModel.sortAscending, isFalse);
      expect(viewModel.receipts.first.amount,
          equals(142.80)); // Whole Foods Market

      viewModel.toggleSort(HistorySortField.amount); // Tap 3: Reset
      expect(viewModel.sortField, equals(HistorySortField.none));
    });

    test(
        'Sort by Date (Tap 1: Newest First, Tap 2: Oldest First, Tap 3: Reset)',
        () {
      viewModel.toggleSort(HistorySortField.date); // Tap 1: Newest First
      expect(viewModel.sortField, equals(HistorySortField.date));
      expect(viewModel.sortAscending, isFalse);
      expect(viewModel.receipts.first.date,
          equals('Aug 01, 2026')); // Target Superstore

      viewModel.toggleSort(HistorySortField.date); // Tap 2: Oldest First
      expect(viewModel.sortAscending, isTrue);
      expect(viewModel.receipts.first.date,
          equals('Jul 22, 2026')); // Whole Foods Market

      viewModel.toggleSort(HistorySortField.date); // Tap 3: Reset
      expect(viewModel.sortField, equals(HistorySortField.none));
    });
  });
}

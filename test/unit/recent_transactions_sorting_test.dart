// File: test/unit/recent_transactions_sorting_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardViewModel Recent Transactions Ordering Tests', () {
    test('recentTransactions returns receipts sorted by createdAt descending (latest to earliest)', () async {
      final repo = ReceiptRepository.instance;
      final now = DateTime.now();

      final rOld = Receipt(
        id: 'recent-test-1',
        merchant: 'Old Merchant',
        date: '2026-08-01',
        amount: 10.0,
        currency: 'USD',
        category: 'Dining',
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final rMid = Receipt(
        id: 'recent-test-2',
        merchant: 'Mid Merchant',
        date: '2026-08-05',
        amount: 20.0,
        currency: 'USD',
        category: 'Groceries',
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final rNew = Receipt(
        id: 'recent-test-3',
        merchant: 'Newest Merchant',
        date: '2026-08-09',
        amount: 30.0,
        currency: 'USD',
        category: 'Transport',
        createdAt: now,
      );

      await repo.saveAllReceipts([rOld, rNew, rMid]);

      final viewModel = DashboardViewModel(repository: repo);
      final recent = viewModel.recentTransactions;

      expect(recent.length, greaterThanOrEqualTo(3));
      // First item must be rNew (latest createdAt)
      expect(recent.first.id, equals('recent-test-3'));
      // Followed by rMid and rOld
      final newIndex = recent.indexWhere((r) => r.id == 'recent-test-3');
      final midIndex = recent.indexWhere((r) => r.id == 'recent-test-2');
      final oldIndex = recent.indexWhere((r) => r.id == 'recent-test-1');

      expect(newIndex, lessThan(midIndex));
      expect(midIndex, lessThan(oldIndex));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:reciept_logging/data/models/receipt.dart';

void main() {
  group('DashboardFilter tests', () {
    test('DashboardFilter default values', () {
      const filter = DashboardFilter();
      expect(filter.category, isNull);
      expect(filter.dateFilter, equals(DateFilter.thisMonth));
    });

    test('DashboardFilter copyWith modifies category and dateFilter', () {
      const filter = DashboardFilter();
      final updated = filter.copyWith(
        category: 'Food & Dining',
        dateFilter: DateFilter.thisWeek,
      );

      expect(updated.category, equals('Food & Dining'));
      expect(updated.dateFilter, equals(DateFilter.thisWeek));
    });

    test('DashboardFilter copyWith clearCategory clears category', () {
      const filter = DashboardFilter(category: 'Shopping');
      final cleared = filter.copyWith(clearCategory: true);

      expect(cleared.category, isNull);
      expect(cleared.dateFilter, equals(DateFilter.thisMonth));
    });
  });

  group('Receipt model calculations', () {
    test('Calculates total spending correctly', () {
      final receipts = [
        Receipt()
          ..merchantName = 'Store A'
          ..totalAmount = 25.50
          ..date = DateTime.now()
          ..category = 'Shopping',
        Receipt()
          ..merchantName = 'Cafe B'
          ..totalAmount = 14.50
          ..date = DateTime.now()
          ..category = 'Food & Dining',
      ];

      final total = receipts.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
      expect(total, equals(40.00));
    });
  });
}

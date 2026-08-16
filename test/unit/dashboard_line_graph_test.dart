// File: test/unit/dashboard_line_graph_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardViewModel Monthly Spending Aggregation & Graph Tooltips', () {
    late DashboardViewModel viewModel;

    setUp(() {
      viewModel = DashboardViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test(
        'monthlySpendingHistory returns exactly graphMonthCount points for 6mo timeline',
        () {
      final history =
          viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);
      expect(history.length, equals(DashboardViewModel.graphMonthCount));
    });

    test('all points are ordered chronologically (oldest-to-newest)', () {
      final history = viewModel.monthlySpendingHistory;
      for (int i = 1; i < history.length; i++) {
        expect(
          history[i].month.isAfter(history[i - 1].month),
          isTrue,
          reason:
              'Point $i (${history[i].label}) should be after point ${i - 1} (${history[i - 1].label})',
        );
      }
    });

    test('all points have non-negative amounts', () {
      final history = viewModel.monthlySpendingHistory;
      for (final point in history) {
        expect(point.amount, greaterThanOrEqualTo(0.0));
      }
    });

    test('labels are formatted as MM/YY', () {
      final history = viewModel.monthlySpendingHistory;
      final labelRegex = RegExp(r'^\d{2}/\d{2}$');
      for (final point in history) {
        expect(
          labelRegex.hasMatch(point.label),
          isTrue,
          reason: '"${point.label}" does not match MM/YY format',
        );
      }
    });

    test('data point tooltip text formats correctly as "amount - MM/YY"', () {
      final point = MonthlySpendingPoint(
        month: DateTime(2026, 3, 1),
        label: '03/26',
        amount: 110.02,
      );
      final tooltipText = '${point.amount.toStringAsFixed(2)} - ${point.label}';
      expect(tooltipText, equals('110.02 - 03/26'));
    });

    test('graphMonthCount constant is 6', () {
      expect(DashboardViewModel.graphMonthCount, equals(6));
    });

    test('_bucketKey produces consistent YYYY-MM strings', () {
      final history = viewModel.monthlySpendingHistory;
      final keyRegex = RegExp(r'^\d{4}-\d{2}$');
      for (final point in history) {
        final key =
            '${point.month.year.toString().padLeft(4, '0')}-${point.month.month.toString().padLeft(2, '0')}';
        expect(keyRegex.hasMatch(key), isTrue);
      }
    });
  });
}

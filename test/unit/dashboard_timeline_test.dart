// File: test/unit/dashboard_timeline_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardViewModel 5-Button Timeline & Caching Unit Tests', () {
    late DashboardViewModel viewModel;

    setUp(() {
      viewModel = DashboardViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Default timeline filter is TimelineFilter.thisMonth', () {
      expect(viewModel.selectedTimeline, equals(TimelineFilter.thisMonth));
    });

    test('thisMonth filter returns daily points for all days in current month', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.thisMonth);
      final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
      expect(points.length, equals(daysInMonth));
    });

    test('Timeline filter switching updates selectedTimeline state', () {
      viewModel.setTimeline(TimelineFilter.threeMonths);
      expect(viewModel.selectedTimeline, equals(TimelineFilter.threeMonths));

      viewModel.setTimeline(TimelineFilter.ytd);
      expect(viewModel.selectedTimeline, equals(TimelineFilter.ytd));
    });

    test('3mo filter returns exactly 3 month data points', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.threeMonths);
      expect(points.length, equals(3));
    });

    test('6mo filter returns exactly 6 month data points', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);
      expect(points.length, equals(6));
    });

    test('12mo filter returns exactly 12 month data points', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.twelveMonths);
      expect(points.length, equals(12));
    });

    test('YTD filter returns current year month count (1 to 12)', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.ytd);
      final currentMonth = DateTime.now().month;
      expect(points.length, equals(currentMonth));
    });

    test('Calculated timeline results are cached and retrieved on subsequent calls', () {
      final firstFetch = viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);
      final secondFetch = viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);

      // Verify reference equality (same cached instance returned)
      expect(identical(firstFetch, secondFetch), isTrue);
    });

    test('All-time timeline returns points starting from earliest receipt month', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.allTime);
      expect(points.length, greaterThanOrEqualTo(3));
      for (final p in points) {
        expect(p.amount, greaterThanOrEqualTo(0.0));
      }
    });
  });
}

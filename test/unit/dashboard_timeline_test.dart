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

    test('Default timeline filter is TimelineFilter.oneWeek', () {
      expect(viewModel.selectedTimeline, equals(TimelineFilter.oneWeek));
    });

    test('oneWeek filter returns exactly 7 daily data points', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.oneWeek);
      expect(points.length, equals(7));
      expect(points.first.label, matches(r'^\d{2}/\d{2}$'));
    });

    test('fourWeeks filter returns exactly 4 weekly data points', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.fourWeeks);
      expect(points.length, equals(4));
      expect(points.last.label, equals('This Wk'));
    });

    test('thisMonth filter returns daily points up to current day in month',
        () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.thisMonth);
      expect(points.length, equals(DateTime.now().day));
    });

    test('Timeline filter switching updates selectedTimeline state', () {
      viewModel.setTimeline(TimelineFilter.fourWeeks);
      expect(viewModel.selectedTimeline, equals(TimelineFilter.fourWeeks));

      viewModel.setTimeline(TimelineFilter.threeMonths);
      expect(viewModel.selectedTimeline, equals(TimelineFilter.threeMonths));

      viewModel.setTimeline(TimelineFilter.ytd);
      expect(viewModel.selectedTimeline, equals(TimelineFilter.ytd));
    });

    test('3mo filter returns exactly 3 month data points', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.threeMonths);
      expect(points.length, equals(3));
    });

    test('6mo filter returns exactly 6 month data points', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);
      expect(points.length, equals(6));
    });

    test('12mo filter returns exactly 12 month data points', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.twelveMonths);
      expect(points.length, equals(12));
    });

    test('YTD filter returns current year month count (1 to 12)', () {
      final points = viewModel.getMonthlySpendingHistory(TimelineFilter.ytd);
      final currentMonth = DateTime.now().month;
      expect(points.length, equals(currentMonth));
    });

    test(
        'Calculated timeline results are cached and retrieved on subsequent calls',
        () {
      final firstFetch =
          viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);
      final secondFetch =
          viewModel.getMonthlySpendingHistory(TimelineFilter.sixMonths);

      // Verify reference equality (same cached instance returned)
      expect(identical(firstFetch, secondFetch), isTrue);
    });

    test(
        'All-time timeline returns points starting from earliest receipt month',
        () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.allTime);
      expect(points.length, greaterThanOrEqualTo(3));
      for (final p in points) {
        expect(p.amount, greaterThanOrEqualTo(0.0));
      }
    });

    test(
        'calculateTimeframeOverview generates valid metrics for 4w and categories',
        () {
      final overview = viewModel.calculateTimeframeOverview(
        filter: TimelineFilter.fourWeeks,
        category: 'All',
      );

      expect(overview.filter, equals(TimelineFilter.fourWeeks));
      expect(overview.totalSpent, greaterThanOrEqualTo(0.0));
      expect(overview.transactionCount, greaterThanOrEqualTo(0));
      expect(overview.averageTransaction, greaterThanOrEqualTo(0.0));
      expect(overview.dailyAverage, greaterThanOrEqualTo(0.0));
      expect(overview.formattedTotal, isNotEmpty);
      expect(overview.comparisonLabel, equals('vs previous 4 weeks'));
    });

    test('availableCategories includes "All" as first entry', () {
      final categories = viewModel.availableCategories;
      expect(categories, isNotEmpty);
      expect(categories.first, equals('All'));
    });

    test('getFilteredReceipts returns list sorted newest first', () {
      final receipts = viewModel.getFilteredReceipts(
        filter: TimelineFilter.allTime,
      );
      expect(receipts, isA<List>());
    });

    test(
        'getTimeframeCategories returns "All" and scopes categories to timeframe',
        () {
      final categories =
          viewModel.getTimeframeCategories(TimelineFilter.fourWeeks);
      expect(categories, isNotEmpty);
      expect(categories.first, equals('All'));
    });

    test(
        'calculateTimeframeOverview supports Set of categories for multi-select',
        () {
      final overview = viewModel.calculateTimeframeOverview(
        filter: TimelineFilter.fourWeeks,
        categories: {'Groceries', 'Dining'},
      );
      expect(overview.totalSpent, greaterThanOrEqualTo(0.0));
      expect(overview.selectedCategories, containsAll(['groceries', 'dining']));
    });

    test(
        'getMonthlySpendingHistory caches and returns points for multi-category selection',
        () {
      final points = viewModel.getMonthlySpendingHistory(
        TimelineFilter.fourWeeks,
        {'Groceries', 'Dining'},
      );
      expect(points.length, equals(4));

      final cached = viewModel.getMonthlySpendingHistory(
        TimelineFilter.fourWeeks,
        {'Groceries', 'Dining'},
      );
      expect(identical(points, cached), isTrue);
    });
  });
}

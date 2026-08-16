// File: test/unit/spending_summary_carousel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardViewModel Spending Summary 6-Element Carousel & Caching Tests', () {
    late DashboardViewModel viewModel;

    setUp(() {
      viewModel = DashboardViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('getSpendingSummary returns valid data for all 6 periods', () {
      final periods = [
        SpendingSummaryPeriod.oneMonth,
        SpendingSummaryPeriod.threeMonths,
        SpendingSummaryPeriod.sixMonths,
        SpendingSummaryPeriod.twelveMonths,
        SpendingSummaryPeriod.ytd,
        SpendingSummaryPeriod.allTime,
      ];

      for (final period in periods) {
        final summary = viewModel.getSpendingSummary(period);
        expect(summary.totalAmount, greaterThanOrEqualTo(0.0));
        expect(summary.transactionCount, greaterThanOrEqualTo(0));
        expect(summary.title, isNotEmpty);
        expect(summary.formattedTotal, isNotEmpty);
        expect(summary.subtitle, contains('transactions'));
      }
    });

    test('Calculated summary data is cached and retrieved on subsequent calls', () {
      final firstFetch = viewModel.getSpendingSummary(SpendingSummaryPeriod.threeMonths);
      final secondFetch = viewModel.getSpendingSummary(SpendingSummaryPeriod.threeMonths);

      // Verify reference equality (same cached instance returned)
      expect(identical(firstFetch, secondFetch), isTrue);
    });

    test('Period titles format correctly for all 6 slides', () {
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.oneMonth).title,
        equals('TOTAL SPENT THIS MONTH'),
      );
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.threeMonths).title,
        equals('TOTAL SPENT LAST 3 MONTHS'),
      );
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.sixMonths).title,
        equals('TOTAL SPENT LAST 6 MONTHS'),
      );
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.twelveMonths).title,
        equals('TOTAL SPENT LAST 12 MONTHS'),
      );
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.ytd).title,
        equals('TOTAL SPENT YEAR TO DATE'),
      );
      expect(
        viewModel.getSpendingSummary(SpendingSummaryPeriod.allTime).title,
        equals('TOTAL SPENT ALL TIME'),
      );
    });

    test('Comparison labels and percentage changes populate for periods 1M-YTD and omit for allTime', () {
      final m1 = viewModel.getSpendingSummary(SpendingSummaryPeriod.oneMonth);
      expect(m1.comparisonLabel, equals('compared to last month'));
      expect(m1.percentageChange, isNotNull);

      final m3 = viewModel.getSpendingSummary(SpendingSummaryPeriod.threeMonths);
      expect(m3.comparisonLabel, equals('compared to last 3 months'));

      final ytd = viewModel.getSpendingSummary(SpendingSummaryPeriod.ytd);
      expect(ytd.comparisonLabel, equals('compared to last year'));

      final allTime = viewModel.getSpendingSummary(SpendingSummaryPeriod.allTime);
      expect(allTime.comparisonLabel, isNull);
      expect(allTime.percentageChange, isNull);
    });
  });
}

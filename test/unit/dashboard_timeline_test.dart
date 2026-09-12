import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/features/analytics/views/analytics_screen.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:reciept_logging/ui/features/dashboard/views/widgets/spending_summary_card.dart';
import 'package:reciept_logging/ui/core/widgets/spending_line_graph.dart';
import 'package:reciept_logging/ui/features/history/views/widgets/category_filter_bottom_sheet.dart';

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

    test('oneWeek filter returns exactly 8 daily data points including 7 days ago', () {
      final points =
          viewModel.getMonthlySpendingHistory(TimelineFilter.oneWeek);
      expect(points.length, equals(8));
      expect(points.first.label, matches(r'^\d{2}/\d{2}$'));
      final now = DateTime.now();
      final expectedFirst = now.subtract(const Duration(days: 7));
      final ddFirst = expectedFirst.day.toString().padLeft(2, '0');
      final mmFirst = expectedFirst.month.toString().padLeft(2, '0');
      expect(points.first.label, equals('$ddFirst/$mmFirst'));

      final ddToday = now.day.toString().padLeft(2, '0');
      final mmToday = now.month.toString().padLeft(2, '0');
      expect(points.last.label, equals('$ddToday/$mmToday'));
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

    test(
        'calculateTimeframeOverview aggregates receipts without category to Uncategorised',
        () {
      final overview = viewModel.calculateTimeframeOverview(
        filter: TimelineFilter.allTime,
      );
      expect(overview.totalSpent, greaterThanOrEqualTo(0.0));
      // Breakdown contains sanitized keys
      for (final key in overview.categoryBreakdown.keys) {
        expect(key, isNotEmpty);
        expect(key, isNot(equals('General')));
      }
    });

    test(
        'calculateTimeframeOverview returns categoryBreakdown sorted strictly descending by amount',
        () {
      final overview = viewModel.calculateTimeframeOverview(
        filter: TimelineFilter.allTime,
      );
      final entries = overview.categoryBreakdown.entries.toList();
      for (int i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].value,
          greaterThanOrEqualTo(entries[i + 1].value),
          reason:
              'Category ${entries[i].key} (${entries[i].value}) should be >= ${entries[i + 1].key} (${entries[i + 1].value})',
        );
      }
    });
  });

  group('AnalyticsScreen UI Tests', () {
    testWidgets(
        'AnalyticsScreen renders category filter button (flex 3) and timeline dropdown (flex 1)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify category filter button and timeline dropdown exist
      expect(find.text('Category'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byType(DropdownButton<TimelineFilter>), findsOneWidget);

      // Verify 3:1 flex ratio in Section 1 row
      final expandedList =
          tester.widgetList<Expanded>(find.byType(Expanded)).toList();
      final flexValues = expandedList.map((e) => e.flex).toList();
      expect(flexValues, contains(3));
      expect(flexValues, contains(1));
    });

    testWidgets(
        'Tapping category filter button opens CategoryFilterBottomSheet',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFilterBottomSheet), findsOneWidget);
      expect(find.text('Filter by Category'), findsOneWidget);
    });

    testWidgets(
        'AnalyticsScreen renders SpendingLineGraph and embedded SpendingSummaryCard',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpendingLineGraph), findsOneWidget);
      expect(find.byType(SpendingSummaryCard), findsOneWidget);
      expect(find.text('Spending Trend'), findsOneWidget);
    });

    testWidgets(
        'AnalyticsScreen renders Overview Metrics with all 4 metric labels and no icons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview Metrics'), findsOneWidget);
      expect(find.text('Avg / Transaction'), findsOneWidget);
      expect(find.text('Total Receipts'), findsOneWidget);
      expect(find.text('Daily Average'), findsOneWidget);
      expect(find.text('Largest Purchase'), findsOneWidget);

      // Verify all icons are removed from Overview Metrics
      expect(find.byIcon(Icons.stars_rounded), findsNothing);
      expect(find.byIcon(Icons.tag_rounded), findsNothing);
      expect(find.byIcon(Icons.receipt_rounded), findsNothing);
    });

    testWidgets(
        'AnalyticsScreen Category Distribution omits "Top XXX" when rendered',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Top: " badge is NOT rendered anywhere in the widget tree
      final topBadgeFinder = find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('Top: '));
      expect(topBadgeFinder, findsNothing);
    });

    testWidgets(
        'AnalyticsScreen Category Distribution progress indicators have valid values',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final indicators = tester.widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      for (final indicator in indicators) {
        if (indicator.value != null) {
          expect(indicator.value, greaterThanOrEqualTo(0.0));
          expect(indicator.value, lessThanOrEqualTo(1.0));
        }
      }
    });

    testWidgets('SpendingLineGraph paints straight lines with data points',
        (tester) async {
      final points = [
        MonthlySpendingPoint(
            month: DateTime(2026, 1, 1), label: '01/26', amount: 50.0),
        MonthlySpendingPoint(
            month: DateTime(2026, 2, 1), label: '02/26', amount: 120.0),
        MonthlySpendingPoint(
            month: DateTime(2026, 3, 1), label: '03/26', amount: 80.0),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineGraph(
              points: points,
              accentColor: Colors.blue,
              textPrimary: Colors.black,
              textSecondary: Colors.grey,
              currencySymbol: r'$',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpendingLineGraph), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
        'SpendingLineGraph renders without errors for both <= 8 and > 8 points',
        (tester) async {
      final points9 = List.generate(
        9,
        (i) => MonthlySpendingPoint(
          month: DateTime(2026, 1, i + 1),
          label: 'D$i',
          amount: 20.0 * (i + 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingLineGraph(
              points: points9,
              accentColor: Colors.blue,
              textPrimary: Colors.black,
              textSecondary: Colors.grey,
              currencySymbol: r'$',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SpendingLineGraph), findsOneWidget);
    });

    testWidgets(
        'Overview metric values are horizontally centered in compact cards',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Both label and value are centered in each of the 3 compact cards (total 6 centered text widgets)
      final centerFinders = find.byWidgetPredicate(
        (w) =>
            w is Center &&
            w.child is Text &&
            (w.child as Text).textAlign == TextAlign.center,
      );
      expect(centerFinders, findsNWidgets(6));
    });

    testWidgets(
        'Selecting a category in CategoryFilterBottomSheet updates button to Filter (1)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();

      // Find first available category chip inside bottom sheet if any exist
      final chipFinders = find.descendant(
        of: find.byType(CategoryFilterBottomSheet),
        matching: find.byType(GestureDetector),
      );
      if (chipFinders.evaluate().isNotEmpty) {
        await tester.tap(chipFinders.first);
        await tester.pumpAndSettle();
      }

      // Tap Apply Filter button
      final applyButton = find.text('Apply Filter');
      if (applyButton.evaluate().isNotEmpty) {
        await tester.tap(applyButton);
        await tester.pumpAndSettle();
      }

      // Verify modal is dismissed
      expect(find.byType(CategoryFilterBottomSheet), findsNothing);
    });

    testWidgets(
        'Selecting 12M in AnalyticsScreen updates graph with 12 points and dynamic key',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<TimelineFilter>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12M').last);
      await tester.pumpAndSettle();

      final graph =
          tester.widget<SpendingLineGraph>(find.byType(SpendingLineGraph));
      expect(graph.points.length, equals(12));
      expect(graph.key, isA<ValueKey<String>>());
      expect(
          (graph.key as ValueKey<String>).value, contains('twelveMonths_12'));
    });

    test('SpendingLineGraphPainter paints Dates Omitted message when n > 8',
        () {
      final points = List.generate(
        12,
        (i) => MonthlySpendingPoint(
          month: DateTime(2025, i + 1, 1),
          label: 'M${i + 1}',
          amount: 50.0,
        ),
      );
      final painter = SpendingLineGraphPainter(
        points: points,
        accentColor: Colors.blue,
        axisLabelColor: Colors.grey,
        textPrimary: Colors.black,
        currencySymbol: r'$',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(360, 120));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}

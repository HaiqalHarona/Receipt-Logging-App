// File: lib/ui/features/dashboard/view_models/dashboard_view_model.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';
import '../../../core/utils/category_utils.dart';

import '../../../../cloud/services/auth_service.dart';

// ── Spending Summary & Monthly Graph Models ──────────────────────────────────

/// Timeline options for the dashboard spending graph and analytics screen.
enum TimelineFilter {
  oneWeek, // 1w (Past 7 days daily breakdown)
  fourWeeks, // 4w (Past 4 weeks weekly breakdown)
  thisMonth, // 1m (This Month daily breakdown)
  threeMonths, // 3mo (Last 3 Months)
  sixMonths, // 6mo (Last 6 Months)
  twelveMonths, // 12mo (Last 12 Months)
  ytd, // YTD (Year-to-date)
  allTime, // All (since first receipt)
}

/// Detailed spending metrics for a specific timeframe and optional category.
class TimeframeSpendingOverview {
  final TimelineFilter filter;
  final String? category;
  final Set<String> selectedCategories;
  final double totalSpent;
  final String formattedTotal;
  final int transactionCount;
  final double averageTransaction;
  final String formattedAverageTransaction;
  final double highestTransaction;
  final String formattedHighestTransaction;
  final String? highestMerchant;
  final double dailyAverage;
  final String formattedDailyAverage;
  final double? previousPeriodTotal;
  final double? percentageChange;
  final String comparisonLabel;
  final Map<String, double> categoryBreakdown;
  final String? topCategoryName;
  final double topCategoryPercent;

  const TimeframeSpendingOverview({
    required this.filter,
    this.category,
    this.selectedCategories = const {},
    required this.totalSpent,
    required this.formattedTotal,
    required this.transactionCount,
    required this.averageTransaction,
    required this.formattedAverageTransaction,
    required this.highestTransaction,
    required this.formattedHighestTransaction,
    this.highestMerchant,
    required this.dailyAverage,
    required this.formattedDailyAverage,
    this.previousPeriodTotal,
    this.percentageChange,
    required this.comparisonLabel,
    required this.categoryBreakdown,
    this.topCategoryName,
    required this.topCategoryPercent,
  });
}

/// Period options for the Spending Summary Carousel (6 elements).
enum SpendingSummaryPeriod {
  oneMonth, // 1m
  threeMonths, // 3m
  sixMonths, // 6m
  twelveMonths, // 12m
  ytd, // YTD
  allTime, // All
}

/// Data payload for a single slide in the Spending Summary Carousel.
class SpendingSummaryData {
  final SpendingSummaryPeriod period;
  final double totalAmount;
  final String formattedTotal;
  final int transactionCount;
  final String title;
  final String subtitle;
  final double? previousTotalAmount;
  final double? percentageChange;
  final String? comparisonLabel;

  const SpendingSummaryData({
    required this.period,
    required this.totalAmount,
    required this.formattedTotal,
    required this.transactionCount,
    required this.title,
    required this.subtitle,
    this.previousTotalAmount,
    this.percentageChange,
    this.comparisonLabel,
  });
}

/// A single point in the monthly spending line graph.
class MonthlySpendingPoint {
  final DateTime month;
  final String label;
  final double amount;

  const MonthlySpendingPoint({
    required this.month,
    required this.label,
    required this.amount,
  });
}

/// ViewModel for [DashboardScreen].
///
/// Reactively aggregates spending totals and recent transactions from
/// [ReceiptRepository], applying live currency conversion via [CurrencyService]
/// and providing calculation caching for spending graphs and timeline selectors.
class DashboardViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  TimelineFilter _selectedTimeline = TimelineFilter.oneWeek;

  bool _isLoggedIn = false;
  String? _username;
  String? _avatarImagePath;

  final Map<String, List<MonthlySpendingPoint>> _timelineCache = {};
  final Map<SpendingSummaryPeriod, SpendingSummaryData> _summaryCache = {};

  DashboardViewModel({
    ReceiptRepository? repository,
    CurrencyService? currencyService,
  })  : _repository = repository ?? ReceiptRepository.instance,
        _currencyService = currencyService ?? CurrencyService.instance {
    _repository.addListener(_onRepositoryChanged);
    _currencyService.addListener(_onRepositoryChanged);
    AuthService.instance.addListener(_onAuthChanged);
    _syncAuthSession();
  }

  void _syncAuthSession() {
    if (AuthService.instance.isLoggedIn) {
      _isLoggedIn = true;
      _username = AuthService.instance.currentUsername;
      _avatarImagePath = AuthService.instance.cachedProfile?.avatarImagePath;
    } else {
      _isLoggedIn = false;
      _username = null;
      _avatarImagePath = null;
    }
  }

  void _onAuthChanged() {
    _syncAuthSession();
    notifyListeners();
  }

  bool get isLoggedIn => AuthService.instance.isLoggedIn ? true : _isLoggedIn;
  String? get username => AuthService.instance.isLoggedIn
      ? (AuthService.instance.currentUsername ?? _username)
      : (_isLoggedIn ? _username : null);
  String? get avatarImagePath => AuthService.instance.isLoggedIn
      ? (AuthService.instance.cachedProfile?.avatarImagePath ??
          _avatarImagePath)
      : _avatarImagePath;

  void setLoginState(
      {required bool isLoggedIn, String? username, String? avatarImagePath}) {
    _isLoggedIn = isLoggedIn;
    _username = username;
    _avatarImagePath = avatarImagePath;
    notifyListeners();
  }

  void _onRepositoryChanged() {
    _timelineCache.clear();
    _summaryCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _currencyService.removeListener(_onRepositoryChanged);
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  // ── Active Timeline Selection ──────────────────────────────────────────────

  TimelineFilter get selectedTimeline => _selectedTimeline;

  void setSelectedTimeline(TimelineFilter filter) {
    if (_selectedTimeline != filter) {
      _selectedTimeline = filter;
      notifyListeners();
    }
  }

  /// Alias for backward compatibility with existing tests/views.
  void setTimeline(TimelineFilter filter) => setSelectedTimeline(filter);

  /// Active target currency symbol (e.g. '$', '€', '£', '¥').
  String get currentSymbol => _currencyService.currentSymbol;

  /// Active target currency code (e.g. 'USD', 'EUR').
  String get currentCurrencyCode => _currencyService.currentCurrency;

  /// Total amount spent across all saved receipts converted to target currency.
  double get totalSpent {
    return _repository.calculateTotalSpent(_currencyService.currentCurrency);
  }

  /// Formatted total spending string (e.g. '$185.40' or '¥24,800').
  String get formattedTotalSpent {
    return _currencyService.format(totalSpent,
        fromCurrencyCode: _currencyService.currentCurrency);
  }

  /// Latest 5 receipts for quick dashboard preview ordered by createdAt descending (latest to earliest).
  List<Receipt> get recentTransactions {
    final sorted = List<Receipt>.from(_repository.receipts)
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    if (sorted.length <= 5) return sorted;
    return sorted.sublist(0, 5);
  }

  /// Converts a specific receipt's price into the active display currency string.
  String formatReceiptPrice(Receipt receipt) {
    return '-${_currencyService.format(receipt.amount, fromCurrencyCode: receipt.currency)}';
  }

  // ── Spending Summary Carousel Aggregation & Caching ─────────────────────────

  /// Calculates or retrieves cached spending summary data for a given [SpendingSummaryPeriod].
  SpendingSummaryData getSpendingSummary(SpendingSummaryPeriod period) {
    if (_summaryCache.containsKey(period)) {
      return _summaryCache[period]!;
    }

    final computed = _calculateSpendingSummary(period);
    _summaryCache[period] = computed;
    return computed;
  }

  SpendingSummaryData _calculateSpendingSummary(SpendingSummaryPeriod period) {
    final now = DateTime.now();
    double total = 0.0;
    double prevTotal = 0.0;
    int count = 0;
    bool hasComparison = period != SpendingSummaryPeriod.allTime;

    for (final r in _repository.receipts) {
      final parsed = _parseDateString(r.date);
      if (parsed == null) continue;

      bool includeCurrent = false;
      bool includePrev = false;

      switch (period) {
        case SpendingSummaryPeriod.oneMonth:
          includeCurrent = parsed.year == now.year && parsed.month == now.month;
          final prevMonth = DateTime(now.year, now.month - 1, 1);
          includePrev =
              parsed.year == prevMonth.year && parsed.month == prevMonth.month;
          break;

        case SpendingSummaryPeriod.threeMonths:
          final currentLimit = DateTime(now.year, now.month - 2, 1);
          final prevStart = DateTime(now.year, now.month - 5, 1);
          includeCurrent = !parsed.isBefore(currentLimit);
          includePrev =
              !parsed.isBefore(prevStart) && parsed.isBefore(currentLimit);
          break;

        case SpendingSummaryPeriod.sixMonths:
          final currentLimit = DateTime(now.year, now.month - 5, 1);
          final prevStart = DateTime(now.year, now.month - 11, 1);
          includeCurrent = !parsed.isBefore(currentLimit);
          includePrev =
              !parsed.isBefore(prevStart) && parsed.isBefore(currentLimit);
          break;

        case SpendingSummaryPeriod.twelveMonths:
          final currentLimit = DateTime(now.year, now.month - 11, 1);
          final prevStart = DateTime(now.year, now.month - 23, 1);
          includeCurrent = !parsed.isBefore(currentLimit);
          includePrev =
              !parsed.isBefore(prevStart) && parsed.isBefore(currentLimit);
          break;

        case SpendingSummaryPeriod.ytd:
          includeCurrent = parsed.year == now.year && parsed.month <= now.month;
          includePrev =
              parsed.year == (now.year - 1) && parsed.month <= now.month;
          break;

        case SpendingSummaryPeriod.allTime:
          includeCurrent = true;
          break;
      }

      final converted = _currencyService.convert(r.amount, r.currency);
      if (includeCurrent) {
        total += converted;
        count++;
      }
      if (hasComparison && includePrev) {
        prevTotal += converted;
      }
    }

    String title;
    String? comparisonLabel;

    switch (period) {
      case SpendingSummaryPeriod.oneMonth:
        title = "TOTAL SPENT THIS MONTH";
        comparisonLabel = "compared to last month";
        break;
      case SpendingSummaryPeriod.threeMonths:
        title = "TOTAL SPENT LAST 3 MONTHS";
        comparisonLabel = "compared to last 3 months";
        break;
      case SpendingSummaryPeriod.sixMonths:
        title = "TOTAL SPENT LAST 6 MONTHS";
        comparisonLabel = "compared to last 6 months";
        break;
      case SpendingSummaryPeriod.twelveMonths:
        title = "TOTAL SPENT LAST 12 MONTHS";
        comparisonLabel = "compared to last 12 months";
        break;
      case SpendingSummaryPeriod.ytd:
        title = "TOTAL SPENT YEAR TO DATE";
        comparisonLabel = "compared to last year";
        break;
      case SpendingSummaryPeriod.allTime:
        title = "TOTAL SPENT ALL TIME";
        comparisonLabel = null;
        break;
    }

    double? percentageChange;
    if (hasComparison) {
      if (prevTotal == 0.0) {
        percentageChange = total == 0.0 ? 0.0 : 100.0;
      } else {
        percentageChange = ((total - prevTotal) / prevTotal) * 100.0;
      }
    }

    final formatted = _currencyService.format(total,
        fromCurrencyCode: _currencyService.currentCurrency);
    final subtitle = "($count transactions) record(s) found.";

    return SpendingSummaryData(
      period: period,
      totalAmount: total,
      formattedTotal: formatted,
      transactionCount: count,
      title: title,
      subtitle: subtitle,
      previousTotalAmount: hasComparison ? prevTotal : null,
      percentageChange: percentageChange,
      comparisonLabel: comparisonLabel,
    );
  }

  // ── Monthly Spending Aggregation & Caching ─────────────────────────────────

  /// Legacy month count constant (for backward compatibility).
  static const int graphMonthCount = 6;

  /// Gets cached or computes monthly spending points for the active timeline.
  List<MonthlySpendingPoint> get monthlySpendingHistory {
    return getMonthlySpendingHistory(_selectedTimeline);
  }

  /// Calculates monthly spending points for a given [TimelineFilter] and optional [categories]
  /// (either a single [String] or [Iterable<String>]), caching the result to avoid redundant loops.
  List<MonthlySpendingPoint> getMonthlySpendingHistory([
    TimelineFilter? filter,
    dynamic categories,
  ]) {
    final target = filter ?? _selectedTimeline;
    final cleanSet = _normalizeCategories(categories);
    final sortedKeys = cleanSet.toList()..sort();
    final cacheKey =
        '${target.name}_${sortedKeys.isEmpty ? "all" : sortedKeys.join(",")}';

    if (_timelineCache.containsKey(cacheKey)) {
      return _timelineCache[cacheKey]!;
    }

    final computed = _calculateTimelinePoints(target, categories: cleanSet);
    _timelineCache[cacheKey] = computed;
    return computed;
  }

  /// Computes timeline spending points for [oneWeek], [fourWeeks], [thisMonth],
  /// [threeMonths], [sixMonths], [twelveMonths], [ytd], or [allTime].
  List<MonthlySpendingPoint> _calculateTimelinePoints(
    TimelineFilter filter, {
    dynamic category,
    Set<String>? categories,
  }) {
    final now = DateTime.now();
    final cleanSet = categories ?? _normalizeCategories(category);

    bool matchesCategory(Receipt r) {
      if (cleanSet.isEmpty) return true;
      final tokens = r.category
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim().toLowerCase())
          .where((c) => c.isNotEmpty);
      return tokens.any((t) => cleanSet.contains(t));
    }

    // ── 1. One Week (1w): Past 7 Days Daily Breakdown ──────────────────────
    if (filter == TimelineFilter.oneWeek) {
      final List<DateTime> days = [];
      final today = DateTime(now.year, now.month, now.day);
      for (int i = 6; i >= 0; i--) {
        days.add(today.subtract(Duration(days: i)));
      }

      final Map<String, double> dayBuckets = {
        for (final d in days) '${d.year}-${d.month}-${d.day}': 0.0
      };

      for (final receipt in _repository.receipts) {
        if (!matchesCategory(receipt)) continue;
        final parsed = _parseDateString(receipt.date);
        if (parsed == null) continue;
        final key = '${parsed.year}-${parsed.month}-${parsed.day}';
        if (dayBuckets.containsKey(key)) {
          final converted =
              _currencyService.convert(receipt.amount, receipt.currency);
          dayBuckets[key] = (dayBuckets[key] ?? 0.0) + converted;
        }
      }

      return days.map((d) {
        final dd = d.day.toString().padLeft(2, '0');
        final mm = d.month.toString().padLeft(2, '0');
        return MonthlySpendingPoint(
          month: d,
          label: '$dd/$mm',
          amount: dayBuckets['${d.year}-${d.month}-${d.day}'] ?? 0.0,
        );
      }).toList();
    }

    // ── 2. Four Weeks (4w): Past 4 Weeks (28 Days in 4 Buckets) ────────────
    if (filter == TimelineFilter.fourWeeks) {
      final today = DateTime(now.year, now.month, now.day);
      final List<Map<String, dynamic>> weeks = [];

      for (int w = 3; w >= 0; w--) {
        final weekStart = today.subtract(Duration(days: (w * 7) + 6));
        final weekEnd = today.subtract(Duration(days: w * 7));
        final label = w == 0 ? 'This Wk' : 'W-$w';
        weeks.add({
          'start': weekStart,
          'end': DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
          'shortLabel': label,
          'amount': 0.0,
          'month': weekStart,
        });
      }

      for (final receipt in _repository.receipts) {
        if (!matchesCategory(receipt)) continue;
        final parsed = _parseDateString(receipt.date);
        if (parsed == null) continue;

        for (final wk in weeks) {
          final start = wk['start'] as DateTime;
          final end = wk['end'] as DateTime;
          if (!parsed.isBefore(start) && !parsed.isAfter(end)) {
            final converted =
                _currencyService.convert(receipt.amount, receipt.currency);
            wk['amount'] = (wk['amount'] as double) + converted;
            break;
          }
        }
      }

      return weeks.map((wk) {
        return MonthlySpendingPoint(
          month: wk['month'] as DateTime,
          label: wk['shortLabel'] as String,
          amount: wk['amount'] as double,
        );
      }).toList();
    }

    // ── 3. This Month (1m): Daily breakdown of current month ───────────────
    if (filter == TimelineFilter.thisMonth) {
      final currentDay = now.day;
      final Map<int, double> dayBuckets = {
        for (int i = 1; i <= currentDay; i++) i: 0.0
      };

      for (final receipt in _repository.receipts) {
        if (!matchesCategory(receipt)) continue;
        final parsed = _parseDateString(receipt.date);
        if (parsed == null) continue;
        if (parsed.year == now.year &&
            parsed.month == now.month &&
            parsed.day <= currentDay) {
          final converted =
              _currencyService.convert(receipt.amount, receipt.currency);
          dayBuckets[parsed.day] = (dayBuckets[parsed.day] ?? 0.0) + converted;
        }
      }

      final mm = now.month.toString().padLeft(2, '0');
      return List.generate(currentDay, (index) {
        final day = index + 1;
        final dd = day.toString().padLeft(2, '0');
        return MonthlySpendingPoint(
          month: DateTime(now.year, now.month, day),
          label: '$dd/$mm',
          amount: dayBuckets[day] ?? 0.0,
        );
      });
    }

    // ── 4. Multi-month ranges (3m, 6m, 12m, ytd, allTime) ──────────────────
    final List<DateTime> months = [];

    switch (filter) {
      case TimelineFilter.oneWeek:
      case TimelineFilter.fourWeeks:
      case TimelineFilter.thisMonth:
        break;
      case TimelineFilter.threeMonths:
        months.addAll(_buildMonthRange(now, 3));
        break;
      case TimelineFilter.sixMonths:
        months.addAll(_buildMonthRange(now, 6));
        break;
      case TimelineFilter.ytd:
        final ytdMonthCount = now.month;
        months.addAll(_buildMonthRange(now, ytdMonthCount));
        break;
      case TimelineFilter.twelveMonths:
        months.addAll(_buildMonthRange(now, 12));
        break;
      case TimelineFilter.allTime:
        DateTime earliest = DateTime(now.year, now.month, 1);
        for (final r in _repository.receipts) {
          final parsed = _parseDateString(r.date);
          if (parsed != null) {
            final monthStart = DateTime(parsed.year, parsed.month, 1);
            if (monthStart.isBefore(earliest)) {
              earliest = monthStart;
            }
          }
        }
        int diffMonths = ((now.year - earliest.year) * 12) +
            (now.month - earliest.month) +
            1;
        if (diffMonths < 3) diffMonths = 3;
        months.addAll(_buildMonthRange(now, diffMonths));
        break;
    }

    final Map<String, double> buckets = {};
    for (final d in months) {
      buckets[_bucketKey(d)] = 0.0;
    }

    for (final receipt in _repository.receipts) {
      if (!matchesCategory(receipt)) continue;
      final parsed = _parseDateString(receipt.date);
      if (parsed == null) continue;
      final key = _bucketKey(DateTime(parsed.year, parsed.month, 1));
      if (!buckets.containsKey(key)) continue;

      final converted = _currencyService.convert(
        receipt.amount,
        receipt.currency,
      );
      buckets[key] = (buckets[key] ?? 0.0) + converted;
    }

    return months.map((d) {
      final mm = d.month.toString().padLeft(2, '0');
      final yy = (d.year % 100).toString().padLeft(2, '0');
      return MonthlySpendingPoint(
        month: d,
        label: '$mm/$yy',
        amount: buckets[_bucketKey(d)] ?? 0.0,
      );
    }).toList();
  }

  /// Normalizes a single category string, list, or set into a clean lowercase token set.
  Set<String> _normalizeCategories(dynamic categoryOrCategories) {
    if (categoryOrCategories == null) return {};
    if (categoryOrCategories is String) {
      final clean =
          CategoryUtils.sanitize(categoryOrCategories).trim().toLowerCase();
      if (clean.isEmpty || clean == 'all') return {};
      return {clean};
    }
    if (categoryOrCategories is Iterable) {
      final result = <String>{};
      for (final item in categoryOrCategories) {
        if (item is String) {
          final clean = CategoryUtils.sanitize(item).trim().toLowerCase();
          if (clean.isNotEmpty && clean != 'all') {
            result.add(clean);
          }
        }
      }
      return result;
    }
    return {};
  }

  /// Calculates the start, end, comparison window dates, and label for [filter].
  ({
    DateTime start,
    DateTime end,
    int daysCount,
    String comparisonLabel,
    DateTime? prevStart,
    DateTime? prevEnd,
  }) _getTimeframeWindow(TimelineFilter filter) {
    final now = DateTime.now();
    DateTime currentStart;
    DateTime currentEnd = now;
    DateTime? prevStart;
    DateTime? prevEnd;
    String comparisonLabel;
    int daysCount = 7;

    switch (filter) {
      case TimelineFilter.oneWeek:
        currentStart = now.subtract(const Duration(days: 7));
        prevStart = now.subtract(const Duration(days: 14));
        prevEnd = currentStart;
        comparisonLabel = 'vs previous 7 days';
        daysCount = 7;
        break;
      case TimelineFilter.fourWeeks:
        currentStart = now.subtract(const Duration(days: 28));
        prevStart = now.subtract(const Duration(days: 56));
        prevEnd = currentStart;
        comparisonLabel = 'vs previous 4 weeks';
        daysCount = 28;
        break;
      case TimelineFilter.thisMonth:
        currentStart = DateTime(now.year, now.month, 1);
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        prevStart = DateTime(prevMonthYear, prevMonth, 1);
        final safeDay = math.min(now.day, 28);
        prevEnd = DateTime(prevMonthYear, prevMonth, safeDay);
        comparisonLabel = 'vs last month';
        daysCount = now.day;
        break;
      case TimelineFilter.threeMonths:
        currentStart = DateTime(now.year, now.month - 3, now.day);
        prevStart = DateTime(now.year, now.month - 6, now.day);
        prevEnd = currentStart;
        comparisonLabel = 'vs previous 3 months';
        daysCount = 90;
        break;
      case TimelineFilter.sixMonths:
        currentStart = DateTime(now.year, now.month - 6, now.day);
        prevStart = DateTime(now.year - 1, now.month, now.day);
        prevEnd = currentStart;
        comparisonLabel = 'vs previous 6 months';
        daysCount = 180;
        break;
      case TimelineFilter.twelveMonths:
        currentStart = DateTime(now.year - 1, now.month, now.day);
        prevStart = DateTime(now.year - 2, now.month, now.day);
        prevEnd = currentStart;
        comparisonLabel = 'vs previous 12 months';
        daysCount = 365;
        break;
      case TimelineFilter.ytd:
        currentStart = DateTime(now.year, 1, 1);
        prevStart = DateTime(now.year - 1, 1, 1);
        prevEnd = DateTime(now.year - 1, now.month, now.day);
        comparisonLabel = 'vs same period last year';
        daysCount = now.difference(currentStart).inDays + 1;
        break;
      case TimelineFilter.allTime:
        currentStart = DateTime(2000, 1, 1);
        prevStart = null;
        prevEnd = null;
        comparisonLabel = 'all-time record';
        daysCount = 1;
        break;
    }

    return (
      start: currentStart,
      end: currentEnd,
      daysCount: daysCount,
      comparisonLabel: comparisonLabel,
      prevStart: prevStart,
      prevEnd: prevEnd,
    );
  }

  /// Calculates a comprehensive spending overview payload for a specific timeframe and optional category/categories.
  TimeframeSpendingOverview calculateTimeframeOverview({
    required TimelineFilter filter,
    dynamic category,
    Iterable<String>? categories,
  }) {
    final cleanSet = categories != null
        ? _normalizeCategories(categories)
        : _normalizeCategories(category);

    final window = _getTimeframeWindow(filter);
    final currentStart = window.start;
    final currentEnd = window.end;
    final prevStart = window.prevStart;
    final prevEnd = window.prevEnd;
    final comparisonLabel = window.comparisonLabel;
    final daysCount = window.daysCount;

    double currentTotal = 0.0;
    double prevTotal = 0.0;
    int transactionCount = 0;
    double highestAmount = 0.0;
    String? highestMerchant;
    final Map<String, double> categoryBreakdown = {};

    for (final receipt in _repository.receipts) {
      final parsed = _parseDateString(receipt.date);
      if (parsed == null) continue;

      final converted =
          _currencyService.convert(receipt.amount, receipt.currency);
      final rTokens = receipt.category
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim())
          .where((c) => c.isNotEmpty)
          .toList();
      final primaryCat = rTokens.isNotEmpty
          ? rTokens.first
          : (receipt.category.trim().isNotEmpty
              ? CategoryUtils.sanitize(receipt.category).trim()
              : 'General');
      final lowerTokens = rTokens.map((t) => t.toLowerCase()).toSet();
      final matchesCat =
          cleanSet.isEmpty || lowerTokens.any((t) => cleanSet.contains(t));

      // Current window
      if (!parsed.isBefore(currentStart) && !parsed.isAfter(currentEnd)) {
        if (matchesCat) {
          currentTotal += converted;
          transactionCount++;
          if (converted > highestAmount) {
            highestAmount = converted;
            highestMerchant = receipt.merchant.trim().isNotEmpty
                ? receipt.merchant.trim()
                : null;
          }
          final breakdownCategory = cleanSet.isEmpty
              ? primaryCat
              : (rTokens.firstWhere(
                  (t) => cleanSet.contains(t.toLowerCase()),
                  orElse: () => primaryCat,
                ));
          categoryBreakdown[breakdownCategory] =
              (categoryBreakdown[breakdownCategory] ?? 0.0) + converted;
        }
      }

      // Comparison window
      if (prevStart != null && prevEnd != null && matchesCat) {
        if (!parsed.isBefore(prevStart) && !parsed.isAfter(prevEnd)) {
          prevTotal += converted;
        }
      }
    }

    final averageTransaction =
        transactionCount > 0 ? currentTotal / transactionCount : 0.0;
    final dailyAverage = daysCount > 0 ? currentTotal / daysCount : 0.0;

    double? percentageChange;
    if (prevStart != null) {
      if (prevTotal == 0.0) {
        percentageChange = currentTotal == 0.0 ? 0.0 : 100.0;
      } else {
        percentageChange = ((currentTotal - prevTotal) / prevTotal) * 100.0;
      }
    }

    String? topCatName;
    double topCatPercent = 0.0;
    if (categoryBreakdown.isNotEmpty) {
      final sortedEntries = categoryBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topEntry = sortedEntries.first;
      topCatName = topEntry.key;
      topCatPercent =
          currentTotal > 0 ? (topEntry.value / currentTotal) * 100.0 : 0.0;
    }

    final formattedTotal = _currencyService.format(currentTotal,
        fromCurrencyCode: _currencyService.currentCurrency);
    final formattedAverage = _currencyService.format(averageTransaction,
        fromCurrencyCode: _currencyService.currentCurrency);
    final formattedHighest = _currencyService.format(highestAmount,
        fromCurrencyCode: _currencyService.currentCurrency);
    final formattedDaily = _currencyService.format(dailyAverage,
        fromCurrencyCode: _currencyService.currentCurrency);

    return TimeframeSpendingOverview(
      filter: filter,
      category: cleanSet.isEmpty ? null : cleanSet.join(', '),
      selectedCategories: cleanSet,
      totalSpent: currentTotal,
      formattedTotal: formattedTotal,
      transactionCount: transactionCount,
      averageTransaction: averageTransaction,
      formattedAverageTransaction: formattedAverage,
      highestTransaction: highestAmount,
      formattedHighestTransaction: formattedHighest,
      highestMerchant: highestMerchant,
      dailyAverage: dailyAverage,
      formattedDailyAverage: formattedDaily,
      previousPeriodTotal: prevStart != null ? prevTotal : null,
      percentageChange: percentageChange,
      comparisonLabel: comparisonLabel,
      categoryBreakdown: categoryBreakdown,
      topCategoryName: topCatName,
      topCategoryPercent: topCatPercent,
    );
  }

  /// Returns sorted distinct atomic categories present in receipts within [filter]'s window,
  /// with 'All' as the first element. Only categories with >= 1 receipt in the timeframe are returned.
  List<String> getTimeframeCategories(TimelineFilter filter) {
    final window = _getTimeframeWindow(filter);
    final set = <String>{};

    for (final r in _repository.receipts) {
      final parsed = _parseDateString(r.date);
      if (parsed == null) continue;
      if (parsed.isBefore(window.start) || parsed.isAfter(window.end)) continue;

      if (r.category.isNotEmpty) {
        for (final token in r.category.split(',')) {
          final clean = CategoryUtils.sanitize(token).trim();
          if (clean.isNotEmpty) {
            set.add(clean);
          }
        }
      }
    }

    final sorted = set.toList()..sort();
    return ['All', ...sorted];
  }

  /// Returns sorted distinct categories from existing receipts plus 'All'.
  List<String> get availableCategories {
    final set = <String>{};
    for (final r in _repository.receipts) {
      if (r.category.isNotEmpty) {
        for (final token in r.category.split(',')) {
          final clean = CategoryUtils.sanitize(token).trim();
          if (clean.isNotEmpty) {
            set.add(clean);
          }
        }
      }
    }
    if (set.isEmpty) {
      set.addAll(['Groceries', 'Dining', 'Shopping', 'Transport', 'Tech']);
    }
    final sorted = set.toList()..sort();
    return ['All', ...sorted];
  }

  /// Filters receipts matching [filter] and optional category or multi-category selection, ordered newest first.
  List<Receipt> getFilteredReceipts({
    required TimelineFilter filter,
    dynamic category,
    Iterable<String>? categories,
  }) {
    final cleanSet = categories != null
        ? _normalizeCategories(categories)
        : _normalizeCategories(category);

    final window = _getTimeframeWindow(filter);
    final currentStart = window.start;
    final currentEnd = window.end;

    final result = <Receipt>[];
    for (final r in _repository.receipts) {
      final parsed = _parseDateString(r.date);
      if (parsed == null) continue;
      if (parsed.isBefore(currentStart) || parsed.isAfter(currentEnd)) continue;
      final rTokens = r.category
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim().toLowerCase())
          .where((c) => c.isNotEmpty);
      if (cleanSet.isNotEmpty && !rTokens.any((t) => cleanSet.contains(t))) {
        continue;
      }
      result.add(r);
    }

    result.sort((a, b) {
      final da = _parseDateString(a.date) ?? DateTime(2000);
      final db = _parseDateString(b.date) ?? DateTime(2000);
      return db.compareTo(da);
    });

    return result;
  }

  /// Builds an ordered list of [count] consecutive months ending at [endMonth].
  List<DateTime> _buildMonthRange(DateTime endMonth, int count) {
    final List<DateTime> months = [];
    for (int i = count - 1; i >= 0; i--) {
      int y = endMonth.year;
      int m = endMonth.month - i;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      months.add(DateTime(y, m, 1));
    }
    return months;
  }

  /// Creates a consistent map key from a [DateTime] (YYYY-MM).
  static String _bucketKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Parses receipt date strings stored as `"MMM DD, YYYY"` or ISO8601.
  static DateTime? _parseDateString(String dateStr) {
    if (dateStr.trim().isEmpty) return null;
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    try {
      final trimmed = dateStr.trim();
      if (trimmed.contains('-') || trimmed.contains('T')) {
        return DateTime.tryParse(trimmed);
      }
      final parts = trimmed.split(RegExp(r'[,\s]+'));
      if (parts.length >= 3) {
        final month = months[parts[0]];
        final day = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (month != null && day != null && year != null) {
          return DateTime(year, month, day);
        }
      }
      return DateTime.tryParse(trimmed);
    } catch (_) {
      return null;
    }
  }
}

// File: lib/ui/features/dashboard/view_models/dashboard_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';

// ── Spending Summary & Monthly Graph Models ──────────────────────────────────

/// Timeline options for the dashboard spending graph.
enum TimelineFilter {
  threeMonths,  // 3mo
  sixMonths,    // 6mo
  ytd,          // YTD (Year-to-date)
  twelveMonths, // 12mo
  allTime,      // All (since first receipt)
}

/// Period options for the Spending Summary Carousel (6 elements).
enum SpendingSummaryPeriod {
  oneMonth,     // 1m
  threeMonths,  // 3m
  sixMonths,    // 6m
  twelveMonths, // 12m
  ytd,          // YTD
  allTime,      // All
}

/// Data payload for a single slide in the Spending Summary Carousel.
class SpendingSummaryData {
  final SpendingSummaryPeriod period;
  final double totalAmount;
  final String formattedTotal;
  final int transactionCount;
  final String title;
  final String subtitle;

  const SpendingSummaryData({
    required this.period,
    required this.totalAmount,
    required this.formattedTotal,
    required this.transactionCount,
    required this.title,
    required this.subtitle,
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
/// and caching timeline & summary aggregations.
class DashboardViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  TimelineFilter _selectedTimeline = TimelineFilter.allTime;
  final Map<TimelineFilter, List<MonthlySpendingPoint>> _timelineCache = {};
  final Map<SpendingSummaryPeriod, SpendingSummaryData> _summaryCache = {};

  DashboardViewModel({
    ReceiptRepository? repository,
    CurrencyService? currencyService,
  })  : _repository = repository ?? ReceiptRepository.instance,
        _currencyService = currencyService ?? CurrencyService.instance {
    _repository.addListener(_onDataChanged);
    _currencyService.addListener(_onDataChanged);
    _repository.init();
  }

  void _onDataChanged() {
    _timelineCache.clear();
    _summaryCache.clear();
    notifyListeners();
  }

  /// Currently active timeline filter option (defaults to [TimelineFilter.allTime]).
  TimelineFilter get selectedTimeline => _selectedTimeline;

  /// Updates active timeline option and triggers UI refresh.
  void setTimeline(TimelineFilter filter) {
    if (_selectedTimeline != filter) {
      _selectedTimeline = filter;
      notifyListeners();
    }
  }

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
    return _currencyService.format(totalSpent, fromCurrencyCode: _currencyService.currentCurrency);
  }

  /// Latest 5 receipts for quick dashboard preview.
  List<Receipt> get recentTransactions {
    final all = _repository.receipts;
    if (all.length <= 5) return all;
    return all.sublist(0, 5);
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
    int count = 0;

    for (final r in _repository.receipts) {
      final parsed = _parseDateString(r.date);
      if (parsed == null) continue;

      bool include = false;
      switch (period) {
        case SpendingSummaryPeriod.oneMonth:
          include = parsed.year == now.year && parsed.month == now.month;
          break;
        case SpendingSummaryPeriod.threeMonths:
          final limit = DateTime(now.year, now.month - 2, 1);
          include = !parsed.isBefore(limit);
          break;
        case SpendingSummaryPeriod.sixMonths:
          final limit = DateTime(now.year, now.month - 5, 1);
          include = !parsed.isBefore(limit);
          break;
        case SpendingSummaryPeriod.twelveMonths:
          final limit = DateTime(now.year, now.month - 11, 1);
          include = !parsed.isBefore(limit);
          break;
        case SpendingSummaryPeriod.ytd:
          final limit = DateTime(now.year, 1, 1);
          include = !parsed.isBefore(limit);
          break;
        case SpendingSummaryPeriod.allTime:
          include = true;
          break;
      }

      if (include) {
        total += _currencyService.convert(r.amount, r.currency);
        count++;
      }
    }

    String title;
    switch (period) {
      case SpendingSummaryPeriod.oneMonth:
        title = "TOTAL SPENT THIS MONTH";
        break;
      case SpendingSummaryPeriod.threeMonths:
        title = "TOTAL SPENT LAST 3 MONTHS";
        break;
      case SpendingSummaryPeriod.sixMonths:
        title = "TOTAL SPENT LAST 6 MONTHS";
        break;
      case SpendingSummaryPeriod.twelveMonths:
        title = "TOTAL SPENT LAST 12 MONTHS";
        break;
      case SpendingSummaryPeriod.ytd:
        title = "TOTAL SPENT YEAR TO DATE";
        break;
      case SpendingSummaryPeriod.allTime:
        title = "TOTAL SPENT ALL TIME";
        break;
    }

    final formatted = _currencyService.format(total, fromCurrencyCode: _currencyService.currentCurrency);
    final subtitle = "Tally from ledger ($count transactions)";

    return SpendingSummaryData(
      period: period,
      totalAmount: total,
      formattedTotal: formatted,
      transactionCount: count,
      title: title,
      subtitle: subtitle,
    );
  }

  // ── Monthly Spending Aggregation & Caching ─────────────────────────────────

  /// Legacy month count constant (for backward compatibility).
  static const int graphMonthCount = 6;

  /// Gets cached or computes monthly spending points for the active timeline.
  List<MonthlySpendingPoint> get monthlySpendingHistory {
    return getMonthlySpendingHistory(_selectedTimeline);
  }

  /// Calculates monthly spending points for a given [TimelineFilter] and caches the result.
  List<MonthlySpendingPoint> getMonthlySpendingHistory([TimelineFilter? filter]) {
    final target = filter ?? _selectedTimeline;
    if (_timelineCache.containsKey(target)) {
      return _timelineCache[target]!;
    }

    final computed = _calculateTimelinePoints(target);
    _timelineCache[target] = computed;
    return computed;
  }

  /// Computes monthly spending points for a specified [TimelineFilter].
  List<MonthlySpendingPoint> _calculateTimelinePoints(TimelineFilter filter) {
    final now = DateTime.now();
    final List<DateTime> months = [];

    switch (filter) {
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
        int diffMonths = ((now.year - earliest.year) * 12) + (now.month - earliest.month) + 1;
        if (diffMonths < 3) diffMonths = 3;
        months.addAll(_buildMonthRange(now, diffMonths));
        break;
    }

    final Map<String, double> buckets = {};
    for (final d in months) {
      buckets[_bucketKey(d)] = 0.0;
    }

    for (final receipt in _repository.receipts) {
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

  /// Parses receipt date strings stored as `"MMM DD, YYYY"` (e.g. `"Aug 01, 2026"`).
  static DateTime? _parseDateString(String dateStr) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    try {
      final parts = dateStr.trim().split(RegExp(r'[,\s]+'));
      if (parts.length < 3) return null;
      final month = months[parts[0]];
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      if (month == null) return null;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onDataChanged);
    _currencyService.removeListener(_onDataChanged);
    super.dispose();
  }
}

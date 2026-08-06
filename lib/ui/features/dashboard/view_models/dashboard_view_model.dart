// File: lib/ui/features/dashboard/view_models/dashboard_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';

// ── Monthly Spending Data Point & Timeline Filter ─────────────────────────────

/// Timeline options for the dashboard spending graph.
enum TimelineFilter {
  threeMonths,  // 3mo
  sixMonths,    // 6mo
  ytd,          // YTD (Year-to-date)
  twelveMonths, // 12mo
  allTime,      // All (since first receipt)
}

/// A single point in the monthly spending line graph.
///
/// [month] is the first day of that calendar month (for ordering/sorting).
/// [label] is the display string formatted as `MM/YY`.
/// [amount] is the total spent in that month converted to the active currency.
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
/// and caching timeline aggregations.
class DashboardViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  TimelineFilter _selectedTimeline = TimelineFilter.allTime;
  final Map<TimelineFilter, List<MonthlySpendingPoint>> _timelineCache = {};

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

  // ── Monthly Spending Aggregation & Caching ─────────────────────────────────

  /// Legacy month count constant (for backward compatibility).
  static const int graphMonthCount = 6;

  /// Gets cached or computes monthly spending points for the active timeline.
  List<MonthlySpendingPoint> get monthlySpendingHistory {
    return getMonthlySpendingHistory(_selectedTimeline);
  }

  /// Calculates monthly spending points for a given [TimelineFilter] and caches the result.
  ///
  /// Reuses cached results on subsequent calls until [_onDataChanged] clears [_timelineCache].
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
        final ytdMonthCount = now.month; // 1 to 12
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
        // Compute total months from earliest to now
        int diffMonths = ((now.year - earliest.year) * 12) + (now.month - earliest.month) + 1;
        if (diffMonths < 3) diffMonths = 3; // Ensure at least 3 months for graph
        months.addAll(_buildMonthRange(now, diffMonths));
        break;
    }

    final Map<String, double> buckets = {};
    for (final d in months) {
      buckets[_bucketKey(d)] = 0.0;
    }

    // Accumulate receipts into buckets
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

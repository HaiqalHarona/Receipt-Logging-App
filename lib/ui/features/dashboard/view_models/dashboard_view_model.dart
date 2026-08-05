// File: lib/ui/features/dashboard/view_models/dashboard_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';

// ── Monthly Spending Data Point ────────────────────────────────────────────────

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
/// [ReceiptRepository], applying live currency conversion via [CurrencyService].
class DashboardViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

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
    notifyListeners();
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

  // ── Monthly Spending Aggregation ───────────────────────────────────────────

  /// The number of months shown in the spending history graph.
  static const int graphMonthCount = 6;

  /// Returns the last [graphMonthCount] calendar months as ordered data points.
  ///
  /// Each point aggregates all receipts whose [Receipt.date] falls within that
  /// calendar month, converting amounts to the active display currency.
  /// Months with no receipts are included with amount 0.0 so the x-axis is
  /// always fully populated.
  List<MonthlySpendingPoint> get monthlySpendingHistory {
    final now = DateTime.now();
    final Map<String, double> buckets = {};

    // Build ordered bucket keys for the last N months oldest-to-newest.
    final List<DateTime> months = [];
    for (int i = graphMonthCount - 1; i >= 0; i--) {
      int y = now.year;
      int m = now.month - i;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      months.add(DateTime(y, m, 1));
    }

    // Initialise each bucket to 0.0.
    for (final d in months) {
      buckets[_bucketKey(d)] = 0.0;
    }

    // Accumulate receipts into buckets.
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

    // Produce ordered list.
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

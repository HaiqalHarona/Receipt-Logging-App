// File: lib/ui/features/dashboard/view_models/dashboard_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';

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

  @override
  void dispose() {
    _repository.removeListener(_onDataChanged);
    _currencyService.removeListener(_onDataChanged);
    super.dispose();
  }
}

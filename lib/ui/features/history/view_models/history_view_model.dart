// File: lib/ui/features/history/view_models/history_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';

/// ViewModel for [HistoryScreen].
///
/// Provides reactive access to all stored receipts in [ReceiptRepository],
/// with live currency formatting and deletion support.
class HistoryViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  HistoryViewModel({
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

  List<Receipt> get receipts => _repository.receipts;

  String formatReceiptPrice(Receipt receipt) {
    return '-${_currencyService.format(receipt.amount, fromCurrencyCode: receipt.currency)}';
  }

  Future<void> deleteReceipt(String id) async {
    await _repository.deleteReceipt(id);
  }

  @override
  void dispose() {
    _repository.removeListener(_onDataChanged);
    _currencyService.removeListener(_onDataChanged);
    super.dispose();
  }
}

// File: lib/ui/features/verification/view_models/verification_view_model.dart

import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';

/// ViewModel managing state and editing operations for [VerificationScreen].
class VerificationViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  List<Receipt> _receipts = [];
  int _currentIndex = 0;
  bool _isSaving = false;

  VerificationViewModel({ReceiptRepository? repository})
      : _repository = repository ?? ReceiptRepository.instance;

  List<Receipt> get receipts => List.unmodifiable(_receipts);
  int get currentIndex => _currentIndex;
  bool get isSaving => _isSaving;

  Receipt? get currentReceipt =>
      _receipts.isNotEmpty ? _receipts[_currentIndex] : null;

  /// Initializes the ViewModel with parsed receipts from OCR scanner.
  void setReceipts(List<Receipt> initialReceipts) {
    if (initialReceipts.isNotEmpty) {
      _receipts = List.from(initialReceipts);
      _currentIndex = 0;
      notifyListeners();
    }
  }

  /// Updates the currently selected receipt in the review carousel with a new domain model.
  void updateReceipt(Receipt updated) {
    if (_receipts.isEmpty) return;
    _receipts[_currentIndex] = updated;
    notifyListeners();
  }

  /// Updates fields of the currently selected receipt in the review carousel.
  void updateCurrentReceipt({
    String? merchant,
    String? date,
    double? amount,
    String? currency,
    String? category,
  }) {
    if (_receipts.isEmpty) return;

    final old = _receipts[_currentIndex];
    final updated = old.copyWith(
      merchant: merchant ?? old.merchant,
      date: date ?? old.date,
      amount: amount ?? old.amount,
      currency: currency ?? old.currency,
      category: category ?? old.category,
    );

    _receipts[_currentIndex] = updated;
    notifyListeners();
  }

  void nextReceipt() {
    if (_currentIndex < _receipts.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void previousReceipt() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  /// Saves all reviewed receipts to the Repository and triggers callback.
  Future<void> saveAllReceipts(VoidCallback onSuccess) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _repository.saveAllReceipts(_receipts);
      onSuccess();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

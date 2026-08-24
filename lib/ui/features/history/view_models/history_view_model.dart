// File: lib/ui/features/history/view_models/history_view_model.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';
import '../../../../services/app_logger_service.dart';
import '../../../core/utils/category_utils.dart';

enum HistorySortField { none, name, amount, date }

/// ViewModel for [HistoryScreen].
///
/// Provides reactive access to all stored receipts in [ReceiptRepository],
/// with search, multi-category filtering, name/amount/date sorting with 3-tap reset,
/// live currency formatting, and deletion support.
class HistoryViewModel extends ChangeNotifier {
  final ReceiptRepository _repository;
  final CurrencyService _currencyService;

  String _searchQuery = '';
  Timer? _debounceTimer;
  Set<String> _selectedCategories = {};
  HistorySortField _sortField = HistorySortField.none;
  int _sortStep = 0; // 0 = none, 1 = initial direction, 2 = flipped direction
  bool _sortAscending = true;

  HistoryViewModel({
    ReceiptRepository? repository,
    CurrencyService? currencyService,
  })  : _repository = repository ?? ReceiptRepository.instance,
        _currencyService = currencyService ?? CurrencyService.instance {
    AppLogger.debug('VM', 'HistoryViewModel initialized');
    _repository.addListener(_onDataChanged);
    _currencyService.addListener(_onDataChanged);
    _repository.init();
  }

  void _onDataChanged() {
    notifyListeners();
  }

  String get searchQuery => _searchQuery;
  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
  HistorySortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  /// Returns unique list of all categories across existing receipts.
  List<String> get availableCategories {
    final categories = <String>{};
    for (final r in _repository.receipts) {
      if (r.category.isNotEmpty) {
        for (final cat in r.category.split(', ')) {
          final clean = CategoryUtils.sanitize(cat);
          if (clean.isNotEmpty) {
            categories.add(clean);
          }
        }
      }
    }
    final sorted = categories.toList()..sort();
    return sorted;
  }

  /// Sets the search query with a 500ms debounce.
  void setSearchQuery(String query) {
    AppLogger.debug('VM', 'HistoryViewModel setSearchQuery: "$query"');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query.trim().toLowerCase();
      notifyListeners();
    });
  }

  /// Toggles a category selection for filtering.
  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    AppLogger.debug('VM',
        'HistoryViewModel toggleCategory "$category" (active: $_selectedCategories)');
    notifyListeners();
  }

  /// Clears all active category filters.
  void clearCategories() {
    AppLogger.debug('VM', 'HistoryViewModel clearCategories');
    _selectedCategories.clear();
    notifyListeners();
  }

  /// Sets multiple selected categories at once.
  void setCategories(Set<String> categories) {
    AppLogger.debug('VM', 'HistoryViewModel setCategories: $categories');
    _selectedCategories = Set.from(categories);
    notifyListeners();
  }

  /// Cycles sort field: Tap 1 (Activate), Tap 2 (Flip direction), Tap 3 (Reset).
  void toggleSort(HistorySortField field) {
    if (_sortField != field) {
      _sortField = field;
      _sortStep = 1;
      _sortAscending = field == HistorySortField.date
          ? false
          : true; // Date defaults to Newest first
    } else if (_sortStep == 1) {
      _sortStep = 2;
      _sortAscending = !_sortAscending;
    } else {
      _sortField = HistorySortField.none;
      _sortStep = 0;
      _sortAscending = true;
    }
    AppLogger.debug('VM',
        'HistoryViewModel toggleSort field: $field, step: $_sortStep, asc: $_sortAscending');
    notifyListeners();
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.trim().split(' ');
      final months = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec'
      ];
      if (parts.length == 3) {
        final monthStr = parts[0].toLowerCase().substring(0, 3);
        final month = months.indexOf(monthStr) + 1;
        final day = int.parse(parts[1].replaceAll(',', ''));
        final year = int.parse(parts[2]);
        if (month > 0) return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Returns stored receipts filtered by search query and category filters, sorted by selected field.
  List<Receipt> get receipts {
    List<Receipt> result = List.from(_repository.receipts);

    // 1. Search Query Filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((r) {
        final merchantMatch = r.merchant.toLowerCase().contains(_searchQuery);
        final categoryMatch = r.category.toLowerCase().contains(_searchQuery);
        final dateMatch = r.date.toLowerCase().contains(_searchQuery);
        final itemsMatch =
            r.items.any((item) => item.toLowerCase().contains(_searchQuery));
        final lineItemsMatch = r.lineItems
            .any((li) => li.description.toLowerCase().contains(_searchQuery));
        return merchantMatch ||
            categoryMatch ||
            dateMatch ||
            itemsMatch ||
            lineItemsMatch;
      }).toList();
    }

    // 2. Multi-Category Filter
    if (_selectedCategories.isNotEmpty) {
      final normalizedSelected = _selectedCategories
          .map((c) => CategoryUtils.sanitize(c).trim().toLowerCase())
          .toSet();

      result = result.where((r) {
        final rCats = r.category
            .split(',')
            .map((c) => CategoryUtils.sanitize(c).trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toSet();

        return normalizedSelected.any((selected) => rCats.contains(selected));
      }).toList();
    }

    // 3. Sorting
    if (_sortField == HistorySortField.name) {
      result.sort((a, b) {
        final comp =
            a.merchant.toLowerCase().compareTo(b.merchant.toLowerCase());
        return _sortAscending ? comp : -comp;
      });
    } else if (_sortField == HistorySortField.amount) {
      result.sort((a, b) {
        final comp = a.amount.compareTo(b.amount);
        return _sortAscending ? comp : -comp;
      });
    } else if (_sortField == HistorySortField.date) {
      result.sort((a, b) {
        final dtA = _parseDate(a.date);
        final dtB = _parseDate(b.date);
        final comp = dtA.compareTo(dtB);
        return _sortAscending ? comp : -comp;
      });
    }

    return List.unmodifiable(result);
  }

  String formatReceiptPrice(Receipt receipt) {
    return '-${_currencyService.format(receipt.amount, fromCurrencyCode: receipt.currency)}';
  }

  Future<void> deleteReceipt(String id) async {
    AppLogger.info('VM', 'HistoryViewModel deleteReceipt id: $id');
    await _repository.deleteReceipt(id);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _repository.removeListener(_onDataChanged);
    _currencyService.removeListener(_onDataChanged);
    super.dispose();
  }
}

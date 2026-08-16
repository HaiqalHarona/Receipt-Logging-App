// File: lib/services/currency_service.dart

import 'package:flutter/foundation.dart';

/// Centralized Currency Service for live currency conversion and symbol formatting.
///
/// Converts receipt amounts between currencies and notifies listeners when
/// the user changes their preferred target currency in Settings.
class CurrencyService extends ChangeNotifier {
  static final CurrencyService instance = CurrencyService._internal();
  CurrencyService._internal();

  String _currentCurrency = 'USD';

  /// Currently selected target currency code (e.g. 'USD', 'EUR', 'GBP').
  String get currentCurrency => _currentCurrency;

  /// Currency definitions and exchange rates relative to USD (1.0).
  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'USD': CurrencyInfo(
        code: 'USD', symbol: '\$', name: 'US Dollar', rateFromUsd: 1.0),
    'EUR':
        CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', rateFromUsd: 0.92),
    'GBP': CurrencyInfo(
        code: 'GBP', symbol: '£', name: 'British Pound', rateFromUsd: 0.78),
    'JPY': CurrencyInfo(
        code: 'JPY', symbol: '¥', name: 'Japanese Yen', rateFromUsd: 155.0),
    'CAD': CurrencyInfo(
        code: 'CAD',
        symbol: 'CA\$',
        name: 'Canadian Dollar',
        rateFromUsd: 1.38),
    'AUD': CurrencyInfo(
        code: 'AUD',
        symbol: 'A\$',
        name: 'Australian Dollar',
        rateFromUsd: 1.52),
    'SGD': CurrencyInfo(
        code: 'SGD',
        symbol: 'S\$',
        name: 'Singapore Dollar',
        rateFromUsd: 1.35),
    'MYR': CurrencyInfo(
        code: 'MYR',
        symbol: 'RM',
        name: 'Malaysian Ringgit',
        rateFromUsd: 4.65),
  };

  /// Symbol for the currently active currency (e.g. '$', '€', '£', 'RM').
  String get currentSymbol =>
      supportedCurrencies[_currentCurrency]?.symbol ?? '\$';

  /// Updates the user's preferred currency and triggers UI recalculation.
  void setCurrency(String newCurrencyCode) {
    if (supportedCurrencies.containsKey(newCurrencyCode) &&
        _currentCurrency != newCurrencyCode) {
      _currentCurrency = newCurrencyCode;
      notifyListeners();
    }
  }

  /// Converts [amount] from [fromCurrencyCode] to [toCurrencyCode] (defaulting to [_currentCurrency]).
  double convert(double amount, String fromCurrencyCode,
      [String? toCurrencyCode]) {
    final targetCode = toCurrencyCode ?? _currentCurrency;
    if (fromCurrencyCode == targetCode) return amount;

    final fromInfo =
        supportedCurrencies[fromCurrencyCode] ?? supportedCurrencies['USD']!;
    final toInfo =
        supportedCurrencies[targetCode] ?? supportedCurrencies['USD']!;

    // First convert from source currency to USD base (amount / rateFromUsd)
    final usdAmount = amount / fromInfo.rateFromUsd;
    // Then convert from USD to target currency
    return usdAmount * toInfo.rateFromUsd;
  }

  /// Formats a converted amount with symbol and appropriate decimal places.
  /// Formats negative amounts cleanly as -$2.50 instead of $-2.50.
  String format(double amount, {String? fromCurrencyCode, String? toCurrencyCode}) {
    final converted = convert(amount, fromCurrencyCode ?? _currentCurrency, toCurrencyCode);
    final targetCode = toCurrencyCode ?? _currentCurrency;
    final symbol = supportedCurrencies[targetCode]?.symbol ?? '\$';

    final isNegative = converted < 0;
    final absVal = converted.abs();
    final numStr = targetCode == 'JPY' ? '${absVal.round()}' : absVal.toStringAsFixed(2);
    return isNegative ? '-$symbol$numStr' : '$symbol$numStr';
  }
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final double rateFromUsd;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateFromUsd,
  });
}

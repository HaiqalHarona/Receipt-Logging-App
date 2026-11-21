import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cloud/services/user_preferences_service.dart';

/// Centralized Currency Service for live currency conversion, historical rate conversion,
/// and symbol formatting.
///
/// Converts receipt amounts between currencies and notifies listeners when
/// the user changes their preferred target currency in Settings.
class CurrencyService extends ChangeNotifier {
  static final CurrencyService instance = CurrencyService._internal();
  CurrencyService._internal();

  static const String _kSelectedCurrency = 'selected_currency_code';

  String _currentCurrency = 'USD';

  /// Currently selected target currency code (e.g. 'USD', 'EUR', 'GBP', 'SGD').
  String get currentCurrency => _currentCurrency;

  /// Loads persisted currency code from SharedPreferences on app launch.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kSelectedCurrency);
      if (saved != null && supportedCurrencies.containsKey(saved)) {
        _currentCurrency = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Updates the user's preferred currency, saves locally, and syncs to cloud.
  void setCurrency(String newCurrencyCode) {
    if (supportedCurrencies.containsKey(newCurrencyCode) &&
        _currentCurrency != newCurrencyCode) {
      _currentCurrency = newCurrencyCode;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_kSelectedCurrency, newCurrencyCode);
      });
      UserPreferencesService.instance.scheduleSync();
      notifyListeners();
    }
  }

  /// 30 currencies published by European Central Bank / Frankfurter API
  /// with exchange rates relative to USD (1.0).
  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'USD': CurrencyInfo(
        code: 'USD', symbol: '\$', name: 'US Dollar', rateFromUsd: 1.0),
    'EUR': CurrencyInfo(
        code: 'EUR', symbol: '€', name: 'Euro', rateFromUsd: 0.92),
    'GBP': CurrencyInfo(
        code: 'GBP', symbol: '£', name: 'British Pound', rateFromUsd: 0.78),
    'JPY': CurrencyInfo(
        code: 'JPY', symbol: '¥', name: 'Japanese Yen', rateFromUsd: 155.0),
    'CAD': CurrencyInfo(
        code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar', rateFromUsd: 1.38),
    'AUD': CurrencyInfo(
        code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', rateFromUsd: 1.52),
    'SGD': CurrencyInfo(
        code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', rateFromUsd: 1.35),
    'MYR': CurrencyInfo(
        code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', rateFromUsd: 4.65),
    'BRL': CurrencyInfo(
        code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', rateFromUsd: 5.60),
    'CHF': CurrencyInfo(
        code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', rateFromUsd: 0.88),
    'CNY': CurrencyInfo(
        code: 'CNY', symbol: '¥', name: 'Chinese Yuan', rateFromUsd: 7.23),
    'CZK': CurrencyInfo(
        code: 'CZK', symbol: 'Kč', name: 'Czech Koruna', rateFromUsd: 23.2),
    'DKK': CurrencyInfo(
        code: 'DKK', symbol: 'kr', name: 'Danish Krone', rateFromUsd: 6.88),
    'HKD': CurrencyInfo(
        code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar', rateFromUsd: 7.78),
    'HUF': CurrencyInfo(
        code: 'HUF', symbol: 'Ft', name: 'Hungarian Forint', rateFromUsd: 366.0),
    'IDR': CurrencyInfo(
        code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', rateFromUsd: 15800.0),
    'ILS': CurrencyInfo(
        code: 'ILS', symbol: '₪', name: 'Israeli New Shekel', rateFromUsd: 3.70),
    'INR': CurrencyInfo(
        code: 'INR', symbol: '₹', name: 'Indian Rupee', rateFromUsd: 84.0),
    'ISK': CurrencyInfo(
        code: 'ISK', symbol: 'kr', name: 'Icelandic Króna', rateFromUsd: 138.0),
    'KRW': CurrencyInfo(
        code: 'KRW', symbol: '₩', name: 'South Korean Won', rateFromUsd: 1380.0),
    'MXN': CurrencyInfo(
        code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', rateFromUsd: 19.8),
    'NOK': CurrencyInfo(
        code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', rateFromUsd: 10.9),
    'NZD': CurrencyInfo(
        code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', rateFromUsd: 1.66),
    'PHP': CurrencyInfo(
        code: 'PHP', symbol: '₱', name: 'Philippine Peso', rateFromUsd: 58.0),
    'PLN': CurrencyInfo(
        code: 'PLN', symbol: 'zł', name: 'Polish Zloty', rateFromUsd: 4.05),
    'RON': CurrencyInfo(
        code: 'RON', symbol: 'lei', name: 'Romanian Leu', rateFromUsd: 4.58),
    'SEK': CurrencyInfo(
        code: 'SEK', symbol: 'kr', name: 'Swedish Krona', rateFromUsd: 10.6),
    'THB': CurrencyInfo(
        code: 'THB', symbol: '฿', name: 'Thai Baht', rateFromUsd: 34.0),
    'TRY': CurrencyInfo(
        code: 'TRY', symbol: '₺', name: 'Turkish Lira', rateFromUsd: 34.2),
    'ZAR': CurrencyInfo(
        code: 'ZAR', symbol: 'R', name: 'South African Rand', rateFromUsd: 17.6),
  };

  /// Symbol for the currently active currency (e.g. '$', '€', '£', 'S$', 'RM').
  String get currentSymbol =>
      supportedCurrencies[_currentCurrency]?.symbol ?? '\$';

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

  /// Converts [amount] in receipt currency to [toCurrencyCode] (defaulting to [_currentCurrency])
  /// using a historical exchange rate relative to SGD (where 1 unit of receipt currency = [sgdRate] SGD).
  double convertWithHistoricalRate(double amount, double sgdRate,
      [String? toCurrencyCode]) {
    final targetCode = toCurrencyCode ?? _currentCurrency;
    final sgdAmount = amount * sgdRate;
    if (targetCode == 'SGD') return sgdAmount;

    // Convert SGD to targetCode via USD bridge using relative static rates
    final sgdInfo =
        supportedCurrencies['SGD'] ?? supportedCurrencies['USD']!;
    final toInfo =
        supportedCurrencies[targetCode] ?? supportedCurrencies['USD']!;
    final usdAmount = sgdAmount / sgdInfo.rateFromUsd;
    return usdAmount * toInfo.rateFromUsd;
  }

  /// Formats [amount] directly in its own original [currencyCode] without any conversion.
  String formatOriginal(double amount, String currencyCode) {
    final info = supportedCurrencies[currencyCode];
    final symbol = info?.symbol ?? currencyCode;
    final isNegative = amount < 0;
    final absVal = amount.abs();
    final noDecimals = currencyCode == 'JPY' || currencyCode == 'KRW';
    final numStr =
        noDecimals ? '${absVal.round()}' : absVal.toStringAsFixed(2);
    return isNegative ? '-$symbol$numStr' : '$symbol$numStr';
  }

  /// Formats the converted equivalent subtitle (e.g. "≈S$12.23").
  /// Returns null if [fromCurrencyCode] matches [toCurrencyCode] (preferred currency).
  String? formatConvertedSubtitle(double amount, String fromCurrencyCode,
      {double? historicalRate, String? toCurrencyCode}) {
    final targetCode = toCurrencyCode ?? _currentCurrency;
    if (fromCurrencyCode == targetCode) return null;

    final double converted = historicalRate != null
        ? convertWithHistoricalRate(amount, historicalRate, targetCode)
        : convert(amount, fromCurrencyCode, targetCode);

    final symbol = supportedCurrencies[targetCode]?.symbol ?? targetCode;
    final isNegative = converted < 0;
    final absVal = converted.abs();
    final noDecimals = targetCode == 'JPY' || targetCode == 'KRW';
    final numStr =
        noDecimals ? '${absVal.round()}' : absVal.toStringAsFixed(2);
    final formatted = isNegative ? '-$symbol$numStr' : '$symbol$numStr';
    return '≈$formatted';
  }

  /// Formats a converted amount with symbol and appropriate decimal places.
  /// Formats negative amounts cleanly as -$2.50 instead of $-2.50.
  String format(double amount,
      {String? fromCurrencyCode, String? toCurrencyCode}) {
    final converted =
        convert(amount, fromCurrencyCode ?? _currentCurrency, toCurrencyCode);
    final targetCode = toCurrencyCode ?? _currentCurrency;
    final symbol = supportedCurrencies[targetCode]?.symbol ?? '\$';

    final isNegative = converted < 0;
    final absVal = converted.abs();
    final noDecimals = targetCode == 'JPY' || targetCode == 'KRW';
    final numStr =
        noDecimals ? '${absVal.round()}' : absVal.toStringAsFixed(2);
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

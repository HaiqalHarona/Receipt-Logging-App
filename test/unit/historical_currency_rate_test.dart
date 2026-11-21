// File: test/unit/historical_currency_rate_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/currency_service.dart';
import 'package:reciept_logging/ui/features/history/view_models/history_view_model.dart';
import 'package:reciept_logging/ui/features/dashboard/view_models/dashboard_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Historical Currency Rate & Dual-Currency Display Tests', () {
    late CurrencyService currencyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      currencyService = CurrencyService.instance;
      currencyService.setCurrency('SGD');
    });

    test('formatOriginal formats in receipt native currency without conversion', () {
      expect(currencyService.formatOriginal(120.0, 'MYR'), equals('RM120.00'));
      expect(currencyService.formatOriginal(50.5, 'SGD'), equals('S\$50.50'));
      expect(currencyService.formatOriginal(100.0, 'USD'), equals('\$100.00'));
      expect(currencyService.formatOriginal(1500.0, 'JPY'), equals('¥1500'));
      expect(currencyService.formatOriginal(-25.0, 'MYR'), equals('-RM25.00'));
    });

    test('convertWithHistoricalRate converts accurately via SGD anchor', () {
      // 100 MYR at 0.3151 SGD per MYR = 31.51 SGD
      final inSgd = currencyService.convertWithHistoricalRate(100.0, 0.3151, 'SGD');
      expect(inSgd, closeTo(31.51, 0.001));

      // 100 MYR at 0.3151 SGD converted to USD (SGD rateFromUsd: 1.35)
      // 31.51 SGD / 1.35 = 23.34 USD
      final inUsd = currencyService.convertWithHistoricalRate(100.0, 0.3151, 'USD');
      expect(inUsd, closeTo(23.34, 0.05));
    });

    test('formatConvertedSubtitle returns null when currencies match', () {
      final subtitle = currencyService.formatConvertedSubtitle(100.0, 'SGD',
          toCurrencyCode: 'SGD');
      expect(subtitle, isNull);
    });

    test('formatConvertedSubtitle returns tilde-prefixed subtitle when currencies differ', () {
      final subtitle = currencyService.formatConvertedSubtitle(
        100.0,
        'MYR',
        historicalRate: 0.3151,
        toCurrencyCode: 'SGD',
      );
      expect(subtitle, equals('≈S\$31.51'));
    });

    test('Receipt domain model serializes and deserializes currencyRateAtReceiptDate', () {
      const receipt = Receipt(
        id: 'rec_hist_1',
        merchant: 'Kuala Lumpur Mart',
        date: '2024-03-15',
        amount: 88.50,
        currency: 'MYR',
        category: 'Groceries',
        currencyRateAtReceiptDate: 0.28419,
        lineItems: [
          LineItem(
            description: 'Kaya Toast',
            quantity: 2,
            unitPrice: 5.0,
            totalPrice: 10.0,
          ),
        ],
      );

      final json = receipt.toJson();
      expect(json['currency_rate_at_receipt_date'], equals(0.28419));

      final restored = Receipt.fromJson(json);
      expect(restored.currencyRateAtReceiptDate, equals(0.28419));
      expect(restored.amount, equals(88.50));
      expect(restored.currency, equals('MYR'));
    });

    test('HistoryViewModel.formatReceiptPrice displays original receipt currency', () {
      final historyVm = HistoryViewModel();
      const receiptMyr = Receipt(
        id: 'rec_101',
        merchant: 'FamilyMart KL',
        date: '2024-03-15',
        amount: 120.0,
        currency: 'MYR',
        category: 'Food',
        currencyRateAtReceiptDate: 0.28419,
      );

      // Even though active preferred currency is SGD, card displays original MYR
      final priceStr = historyVm.formatReceiptPrice(receiptMyr);
      expect(priceStr, equals('-RM120.00'));
    });

    test('DashboardViewModel.formatReceiptPrice displays original receipt currency', () {
      final dashVm = DashboardViewModel();
      const receiptMyr = Receipt(
        id: 'rec_102',
        merchant: 'Penang Hawker',
        date: '2024-03-15',
        amount: 45.0,
        currency: 'MYR',
        category: 'Food',
        currencyRateAtReceiptDate: 0.28419,
      );

      final priceStr = dashVm.formatReceiptPrice(receiptMyr);
      expect(priceStr, equals('-RM45.00'));
    });
  });
}

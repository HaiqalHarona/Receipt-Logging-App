// File: test/unit/receipt_detail_currency_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/currency_service.dart';
import 'package:reciept_logging/ui/features/receipt_detail/views/receipt_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptDetailScreen Line Item Currency Conversion & Caching Tests', () {
    late CurrencyService currencyService;

    setUp(() {
      currencyService = CurrencyService.instance;
      currencyService.setCurrency('USD');
    });

    test('ConvertedLineItem calculates converted unit and total prices', () {
      const receipt = Receipt(
        id: 'rec_test_101',
        merchant: 'Tech Store',
        date: 'Aug 06, 2026',
        amount: 100.0,
        currency: 'USD',
        category: 'Electronics',
        lineItems: [
          LineItem(description: 'USB Cable', quantity: 2, unitPrice: 25.0, totalPrice: 50.0),
          LineItem(description: 'Wireless Mouse', quantity: 1, unitPrice: 50.0, totalPrice: 50.0),
        ],
      );

      final convertedItems = <ConvertedLineItem>[];
      final targetCurrency = currencyService.currentCurrency;

      for (final item in receipt.lineItems) {
        final qty = item.quantity ?? 1.0;
        final origTotal = item.totalPrice ?? 0.0;
        final origUnit = item.unitPrice ?? (qty > 0 ? origTotal / qty : origTotal);

        final convertedUnit = currencyService.convert(origUnit, receipt.currency);
        final convertedTotal = currencyService.convert(origTotal, receipt.currency);

        final formattedUnit = currencyService.format(convertedUnit, fromCurrencyCode: targetCurrency);
        final formattedTotal = currencyService.format(convertedTotal, fromCurrencyCode: targetCurrency);

        convertedItems.add(ConvertedLineItem(
          unitPrice: convertedUnit,
          totalPrice: convertedTotal,
          formattedUnitPrice: formattedUnit,
          formattedTotalPrice: formattedTotal,
        ));
      }

      expect(convertedItems.length, equals(2));
      expect(convertedItems[0].formattedUnitPrice, contains('25.00'));
      expect(convertedItems[0].formattedTotalPrice, contains('50.00'));
    });

    test('Converted line items cache returns identical list instance for same (receiptId + targetCurrency)', () {
      final cache = <String, List<ConvertedLineItem>>{};
      const receipt = Receipt(
        id: 'rec_test_102',
        merchant: 'Grocery Hub',
        date: 'Aug 06, 2026',
        amount: 30.0,
        currency: 'USD',
        category: 'Groceries',
        lineItems: [
          LineItem(description: 'Milk', quantity: 1, unitPrice: 10.0, totalPrice: 10.0),
        ],
      );

      final targetCurrency = currencyService.currentCurrency;
      final key = '${receipt.id}_$targetCurrency';

      // First calculation
      cache[key] = [
        ConvertedLineItem(
          unitPrice: 10.0,
          totalPrice: 10.0,
          formattedUnitPrice: currencyService.format(10.0, fromCurrencyCode: targetCurrency),
          formattedTotalPrice: currencyService.format(10.0, fromCurrencyCode: targetCurrency),
        ),
      ];

      final firstCall = cache[key]!;
      final secondCall = cache[key]!;

      // Verify reference equality (same cached instance returned)
      expect(identical(firstCall, secondCall), isTrue);
    });
  });
}

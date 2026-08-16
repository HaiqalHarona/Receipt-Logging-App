// File: test/services/api/parse_endpoint_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/models/receipt_models.dart';

void main() {
  group('Parse Endpoint DTO Unit Tests', () {
    test(
        'ScanResponseDto deserializes backend JSON response structure correctly',
        () {
      final jsonResponse = {
        "success": true,
        "data": {
          "id": "rec_123456",
          "merchant_name": "Target Superstore",
          "total_amount": 128.45,
          "subtotal": 120.00,
          "tax_amount": 8.45,
          "currency": "USD",
          "category": "Groceries",
          "date": "2026-08-01T14:30:00Z",
          "raw_text": "TARGET\nTOTAL: 128.45",
          "confidence_score": 0.98,
          "line_items": [
            {
              "description": "Organic Milk 1 Gal",
              "quantity": 1.0,
              "unit_price": 4.99,
              "total_price": 4.99
            },
            {
              "description": "Avocados Bag 5ct",
              "quantity": 2.0,
              "unit_price": 5.00,
              "total_price": 10.00
            }
          ]
        },
        "error": null
      };

      final scanResponse = ScanResponseDto.fromJson(jsonResponse);

      expect(scanResponse.success, isTrue);
      expect(scanResponse.data, isNotNull);

      final receipt = scanResponse.data!;
      expect(receipt.merchantName, equals("Target Superstore"));
      expect(receipt.totalAmount, equals(128.45));
      expect(receipt.currency, equals("USD"));
      expect(receipt.category, equals("Groceries"));
      expect(receipt.date, equals("2026-08-01T14:30:00Z"));
      expect(receipt.lineItems.length, equals(2));
      expect(receipt.lineItems[0].description, equals("Organic Milk 1 Gal"));
      expect(receipt.lineItems[0].totalPrice, equals(4.99));
    });

    test('ReceiptDto serializes to JSON map structure properly', () {
      final lineItem = LineItemDto(
        description: "Espresso Beans",
        quantity: 2.0,
        unitPrice: 14.50,
        totalPrice: 29.00,
      );

      final receipt = ReceiptDto(
        merchantName: "Artisan Coffee Roasters",
        totalAmount: 29.00,
        subtotal: 27.00,
        taxAmount: 2.00,
        currency: "USD",
        category: "Coffee & Drinks",
        date: "2026-08-16T10:00:00Z",
        rawText: "ARTISAN COFFEE\nTOTAL: 29.00",
        lineItems: [lineItem],
      );

      final json = receipt.toJson();

      expect(json['merchant_name'], equals("Artisan Coffee Roasters"));
      expect(json['total_amount'], equals(29.00));
      expect(json['currency'], equals("USD"));
      expect(json['category'], equals("Coffee & Drinks"));
      expect((json['line_items'] as List).length, equals(1));
    });
  });
}

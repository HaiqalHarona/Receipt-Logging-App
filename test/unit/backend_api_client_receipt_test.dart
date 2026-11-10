// File: test/unit/backend_api_client_receipt_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';
import 'package:reciept_logging/cloud/models/receipt_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackendApiClient.fetchReceiptById Tests', () {
    final sampleReceiptJson = <String, dynamic>{
      'id': 'rec-uuid-1234-abcd',
      'user_id': 'user-uuid-999',
      'device_id': 'device-uuid-888',
      'created_at': '2026-10-17T12:30:00Z',
      'receipt_image_path': '/images/rec-uuid-1234-abcd.jpg',
      'receipt': {
        'merchant_name': 'Super Store',
        'total_amount': 75.40,
        'date': '2026-10-17',
        'raw_text': 'Super Store Total 75.40',
        'currency': 'USD',
        'category': 'Groceries',
        'confidence_score': 0.95,
        'subtotal': 70.00,
        'tax_amount': 5.40,
        'notes': 'Weekly groceries',
        'line_items': [
          {
            'description': 'Organic Milk',
            'quantity': 2,
            'unit_price': 4.50,
            'total_price': 9.00,
          },
          {
            'description': 'Fresh Bread',
            'quantity': 1,
            'unit_price': 3.20,
            'total_price': 3.20,
          },
        ],
      },
    };

    test('returns ReceiptRecordDto on HTTP 200 with valid mock JSON', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        if (request.method == 'GET' &&
            request.url.path.endsWith('/receipts/rec-uuid-1234-abcd')) {
          return http.Response(
            jsonEncode(sampleReceiptJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById(
        'rec-uuid-1234-abcd',
        username: 'test_user',
        userToken: 'token_123',
      );

      expect(result, isNotNull);
      expect(result, isA<ReceiptRecordDto>());
      expect(result!.id, equals('rec-uuid-1234-abcd'));
      expect(result.userId, equals('user-uuid-999'));
      expect(result.deviceId, equals('device-uuid-888'));
      expect(result.receiptImagePath, equals('/images/rec-uuid-1234-abcd.jpg'));
      expect(result.createdAt, equals('2026-10-17T12:30:00Z'));
      expect(result.receipt.merchantName, equals('Super Store'));
      expect(result.receipt.totalAmount, equals(75.40));
      expect(result.receipt.subtotal, equals(70.00));
      expect(result.receipt.taxAmount, equals(5.40));
      expect(result.receipt.currency, equals('USD'));
      expect(result.receipt.category, equals('Groceries'));
      expect(result.receipt.confidenceScore, equals(0.95));
      expect(result.receipt.notes, equals('Weekly groceries'));
      expect(result.receipt.lineItems.length, equals(2));
      expect(result.receipt.lineItems[0].description, equals('Organic Milk'));
      expect(result.receipt.lineItems[0].totalPrice, equals(9.00));
      expect(result.receipt.lineItems[1].description, equals('Fresh Bread'));

      // Verify request method and headers
      expect(capturedRequest.method, equals('GET'));
      expect(capturedRequest.headers['X-User-Name'], equals('test_user'));
      expect(capturedRequest.headers['X-User-Token'], equals('token_123'));
    });

    test('returns null on HTTP 404 Not Found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Receipt not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById('non-existent-id');

      expect(result, isNull);
    });

    test('properly URL-encodes receipt IDs with standard UUID', () async {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      late Uri capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode(sampleReceiptJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById(uuid);

      expect(result, isNotNull);
      expect(capturedUri.path.endsWith('/receipts/$uuid'), isTrue);
      expect(capturedUri.toString(), contains('/receipts/$uuid'));
    });

    test('properly URL-encodes receipt IDs with special characters', () async {
      const rawSpecialId = 'rec#123/special?test=1&name=a+b';
      final expectedCleanId = Uri.encodeComponent(rawSpecialId);
      late Uri capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode(sampleReceiptJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById(rawSpecialId);

      expect(result, isNotNull);
      expect(capturedUri.toString(), contains('/receipts/$expectedCleanId'));
      expect(expectedCleanId, equals('rec%23123%2Fspecial%3Ftest%3D1%26name%3Da%2Bb'));
    });

    test('returns null on HTTP 500 server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById('rec-error-500');

      expect(result, isNull);
    });

    test('catches network exceptions and gracefully returns null', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final client = BackendApiClient(httpClient: mockClient);
      final result = await client.fetchReceiptById('rec-network-failure');

      expect(result, isNull);
    });
  });
}

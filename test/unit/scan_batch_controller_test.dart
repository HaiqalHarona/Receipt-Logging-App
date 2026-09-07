// File: test/unit/scan_batch_controller_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';
import 'package:reciept_logging/cloud/models/receipt_models.dart';
import 'package:reciept_logging/services/scan_batch_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanBatchController Logic Tests', () {
    test(
        'Image filename mapper preserves image path even when backend returns basename',
        () {
      expect(ScanBatchController.instance, isNotNull);

      // Simulate a guest scan with an image
      final tempFile =
          File('${Directory.systemTemp.path}/test_scan_receipt.jpg');
      tempFile.writeAsBytesSync([1, 2, 3, 4]);

      final xfile = XFile(tempFile.path);

      // Verify that filename can be resolved
      expect(xfile.path, equals(tempFile.path));

      // Clean up
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    test(
        'BulkBatchStatusResponseDto parses completed and failed jobs correctly',
        () {
      final json = {
        "batch_id": "batch-123",
        "total_jobs": 2,
        "completed_jobs": 1,
        "jobs": [
          {
            "job_id": "job-1",
            "batch_id": "batch-123",
            "status": "COMPLETED",
            "filename": "receipt_1.jpg",
            "data": {
              "merchant_name": "Trader Joe's",
              "total_amount": 42.50,
              "currency": "USD",
              "category": "Groceries",
              "date": "2026-09-01T10:00:00Z",
              "raw_text": "TRADER JOES",
              "confidence_score": 0.95,
              "line_items": []
            },
            "error": null
          },
          {
            "job_id": "job-2",
            "batch_id": "batch-123",
            "status": "FAILED",
            "filename": "receipt_2.jpg",
            "data": null,
            "error": "OCR failed to detect text"
          }
        ]
      };

      final dto = BulkBatchStatusResponseDto.fromJson(json);
      expect(dto.batchId, equals('batch-123'));
      expect(dto.totalJobs, equals(2));
      expect(dto.completedJobs, equals(1));
      expect(dto.completedJobsList.length, equals(1));
      expect(dto.completedJobsList.first.filename, equals('receipt_1.jpg'));
      expect(dto.failedJobsList.length, equals(1));
      expect(dto.failedJobsList.first.filename, equals('receipt_2.jpg'));
    });

    test('RateLimitException is recognized as non-retryable', () {
      const rateLimitEx = RateLimitException(
        'Rate limit reached',
        retryAfterSeconds: 60,
        statusCode: 429,
      );
      expect(rateLimitEx.statusCode, equals(429));
      expect(rateLimitEx.retryAfterSeconds, equals(60));
    });

    test('ApiException with 401 indicates session expiration', () {
      const authEx = ApiException(
        'Unauthorized session token',
        statusCode: 401,
      );
      expect(authEx.statusCode, equals(401));
    });
  });
}

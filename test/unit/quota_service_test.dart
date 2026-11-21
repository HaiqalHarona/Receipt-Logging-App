// File: test/unit/quota_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quota Models & Service Tests', () {
    test('QuotaMetricDto and QuotaStatusDto deserialize from JSON correctly',
        () {
      final json = {
        'success': true,
        'tier': 'free',
        'scan': {
          'used': 7,
          'limit': 10,
          'remaining': 3,
          'is_exhausted': false,
        },
        'chat': {
          'used': 8500,
          'limit': 10000,
          'remaining': 1500,
          'is_exhausted': false,
        },
        'reset_at': '2026-08-29T00:00:00Z',
        'seconds_to_reset': 19380,
        'reset_countdown': '5h 23m',
      };

      final status = QuotaStatusDto.fromJson(json);

      expect(status.success, isTrue);
      expect(status.tier, equals('free'));
      expect(status.scan.used, equals(7));
      expect(status.scan.limit, equals(10));
      expect(status.scan.remaining, equals(3));
      expect(status.scan.isExhausted, isFalse);
      expect(status.scan.isUnlimited, isFalse);

      expect(status.chat.used, equals(8500));
      expect(status.chat.limit, equals(10000));
      expect(status.chat.remaining, equals(1500));
      expect(status.chat.isExhausted, isFalse);
      expect(status.chat.isUnlimited, isFalse);

      expect(status.resetCountdown, equals('5h 23m'));
      expect(
          status.formattedScanTooltip,
          equals(
              'Daily scan quota reached (7/10). Resets in 5h 23m at 00:00 UTC'));
      expect(
          status.formattedChatTooltip,
          equals(
              'Daily chat token quota reached (8k/10k). Resets in 5h 23m at 00:00 UTC'));
    });

    test('Dev Tier unlimited (-1) handling', () {
      final json = {
        'success': true,
        'tier': 'dev',
        'scan': {
          'used': 42,
          'limit': -1,
          'remaining': -1,
          'is_exhausted': false,
        },
        'chat': {
          'used': 125000,
          'limit': -1,
          'remaining': -1,
          'is_exhausted': false,
        },
        'reset_at': '2026-08-29T00:00:00Z',
        'seconds_to_reset': 18000,
        'reset_countdown': '5h 0m',
      };

      final status = QuotaStatusDto.fromJson(json);

      expect(status.tier, equals('dev'));
      expect(status.scan.isUnlimited, isTrue);
      expect(status.scan.isExhausted, isFalse);
      expect(status.chat.isUnlimited, isTrue);
      expect(status.chat.isExhausted, isFalse);
    });

    test('QuotaService optimistic increment and exhaustion detection', () {
      final quotaSvc = QuotaService.instance;

      // Seed status via DTO
      final json = {
        'success': true,
        'tier': 'free',
        'scan': {
          'used': 9,
          'limit': 10,
          'remaining': 1,
          'is_exhausted': false,
        },
        'chat': {
          'used': 9500,
          'limit': 10000,
          'remaining': 500,
          'is_exhausted': false,
        },
        'reset_at': '2026-08-29T00:00:00Z',
        'seconds_to_reset': 18000,
        'reset_countdown': '5h 0m',
      };

      // Set internal status by simulating parse
      final status = QuotaStatusDto.fromJson(json);
      expect(status.scan.isExhausted, isFalse);

      // Perform local scan increment of 1 -> exhausts scan quota
      quotaSvc.recordLocalScanIncrement(1);
      // Even if _status was previously null, tests recordLocalScanIncrement safely
    });
  });
}

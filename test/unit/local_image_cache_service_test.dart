import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/services/local_image_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.createTempSync('cache_test_').path;
      },
    );
  });

  group('LocalImageCacheService Avatar Cache & Revision Tests', () {
    setUp(() async {
      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cache-test-1',
          username: 'CacheTester',
          email: 'cache@example.com',
          createdAt: '2026-08-28T12:00:00Z',
        ),
        userToken: 'mock-cache-token',
      );
    });

    test('Saving avatar increases avatarRevision and notifies listeners',
        () async {
      final initialRevision = LocalImageCacheService.instance.avatarRevision;
      var notified = false;

      void listener() {
        notified = true;
      }

      LocalImageCacheService.instance.addListener(listener);
      addTearDown(
          () => LocalImageCacheService.instance.removeListener(listener));

      // Mock 1x1 dummy JPEG bytes
      final dummyBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];

      await LocalImageCacheService.instance.saveLocalAvatar(
        size: 'medium',
        bytes: dummyBytes,
      );

      expect(LocalImageCacheService.instance.avatarRevision,
          greaterThan(initialRevision));
      expect(notified, isTrue);
    });

    test('evictAvatarCache bumps avatarRevision and notifies listeners',
        () async {
      final initialRevision = LocalImageCacheService.instance.avatarRevision;
      var notified = false;

      void listener() {
        notified = true;
      }

      LocalImageCacheService.instance.addListener(listener);
      addTearDown(
          () => LocalImageCacheService.instance.removeListener(listener));

      await LocalImageCacheService.instance.evictAvatarCache();

      expect(LocalImageCacheService.instance.avatarRevision,
          greaterThan(initialRevision));
      expect(notified, isTrue);
    });
  });
}

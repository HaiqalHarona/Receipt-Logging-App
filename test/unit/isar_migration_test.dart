// test/unit/isar_migration_test.dart

import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/data/local/isar_migration_helper.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.containsKey(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IsarMigrationHelper Parity & Pre-flight Tests', () {
    late Directory tempDir;
    late MockSecureStorage mockStorage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('isar_migration_test_');
      mockStorage = MockSecureStorage();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('needsMigration returns true when db file exists and flag is missing',
        () async {
      final dummyDb = File('${tempDir.path}/default.isar');
      await dummyDb.writeAsString('dummy isar binary content');

      final helper = IsarMigrationHelper(
        directory: tempDir.path,
        instanceName: 'default',
        schemas: [],
        storage: mockStorage,
      );

      expect(await helper.needsMigration(dummyDb), isTrue);
    });

    test(
        'needsMigration returns false and sets flag when db file does not exist (fresh install)',
        () async {
      final nonExistentDb = File('${tempDir.path}/default.isar');

      final helper = IsarMigrationHelper(
        directory: tempDir.path,
        instanceName: 'default',
        schemas: [],
        storage: mockStorage,
      );

      expect(await helper.needsMigration(nonExistentDb), isFalse);
      expect(
        await mockStorage.read(
            key: IsarMigrationHelper.migrationCompleteFlagKey),
        equals('true'),
      );
    });

    test('needsMigration returns false when migration flag is already true',
        () async {
      final dummyDb = File('${tempDir.path}/default.isar');
      await dummyDb.writeAsString('dummy isar binary content');
      await mockStorage.write(
        key: IsarMigrationHelper.migrationCompleteFlagKey,
        value: 'true',
      );

      final helper = IsarMigrationHelper(
        directory: tempDir.path,
        instanceName: 'default',
        schemas: [],
        storage: mockStorage,
      );

      expect(await helper.needsMigration(dummyDb), isFalse);
    });

    test('assertSufficientDiskSpace succeeds when free space is at least 2.5x DB size',
        () async {
      final dummyDb = File('${tempDir.path}/default.isar');
      // 1000 bytes db size -> requires 2500 bytes
      await dummyDb.writeAsBytes(List<int>.filled(1000, 0x42));

      final helper = IsarMigrationHelper(
        directory: tempDir.path,
        instanceName: 'default',
        schemas: [],
        storage: mockStorage,
        freeDiskSpaceProvider: (_) async => 5000, // 5000 >= 2500
      );

      // Should complete without throwing
      await expectLater(
        helper.assertSufficientDiskSpace(dummyDb),
        completes,
      );
    });

    test('assertSufficientDiskSpace throws FileSystemException when free space < 2.5x DB size',
        () async {
      final dummyDb = File('${tempDir.path}/default.isar');
      // 1000 bytes db size -> requires 2500 bytes
      await dummyDb.writeAsBytes(List<int>.filled(1000, 0x42));

      final helper = IsarMigrationHelper(
        directory: tempDir.path,
        instanceName: 'default',
        schemas: [],
        storage: mockStorage,
        freeDiskSpaceProvider: (_) async => 2000, // 2000 < 2500
      );

      expect(
        () => helper.assertSufficientDiskSpace(dummyDb),
        throwsA(isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('Insufficient disk space for Isar database encryption migration'),
        )),
      );
    });
  });
}

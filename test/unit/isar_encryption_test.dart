// test/unit/isar_encryption_test.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/services/crypto_service.dart';

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

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CryptoService cryptoService;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    cryptoService = CryptoService.instance;
    cryptoService.resetForTesting(customStorage: mockStorage);
  });

  group('Isar Storage Key Management Tests', () {
    test('Generates 256-bit hex database encryption key when none exists',
        () async {
      final key = await cryptoService.getOrCreateDatabaseEncryptionKey();
      expect(key, isNotEmpty);
      expect(key.length, equals(64)); // 32 bytes hex encoded = 64 characters

      // Verify stored in mock storage
      final storedKey =
          await mockStorage.read(key: CryptoService.databaseKeyStorageKey);
      expect(storedKey, equals(key));
    });

    test('Reuses existing database encryption key on subsequent calls',
        () async {
      const existingHex =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      await mockStorage.write(
        key: CryptoService.databaseKeyStorageKey,
        value: existingHex,
      );

      final key = await cryptoService.getOrCreateDatabaseEncryptionKey();
      expect(key, equals(existingHex));
    });

    test('Rotates database encryption key and updates storage when requested',
        () async {
      final initialKey = await cryptoService.getOrCreateDatabaseEncryptionKey();
      final rotatedKey = await cryptoService.rotateDatabaseEncryptionKey();

      expect(rotatedKey, isNot(equals(initialKey)));
      expect(rotatedKey.length, equals(64));

      final storedKey =
          await mockStorage.read(key: CryptoService.databaseKeyStorageKey);
      expect(storedKey, equals(rotatedKey));
    });

    test('Caches database key in-memory and clearCachedKeys invalidates cache',
        () async {
      final key1 = await cryptoService.getOrCreateDatabaseEncryptionKey();
      // Remove key from storage; in-memory cache should still return it
      await mockStorage.delete(key: CryptoService.databaseKeyStorageKey);
      final keyFromCache =
          await cryptoService.getOrCreateDatabaseEncryptionKey();
      expect(keyFromCache, equals(key1));

      // After clearing cached keys, it must regenerate since storage is empty
      cryptoService.clearCachedKeys();
      final keyAfterClear =
          await cryptoService.getOrCreateDatabaseEncryptionKey();
      expect(keyAfterClear, isNot(equals(key1)));
      expect(keyAfterClear.length, equals(64));
    });

    test('Rejects invalid short keys from storage and generates valid 256-bit key',
        () async {
      await mockStorage.write(
        key: CryptoService.databaseKeyStorageKey,
        value: 'too_short_key',
      );

      final key = await cryptoService.getOrCreateDatabaseEncryptionKey();
      expect(key.length, equals(64));
      expect(key, isNot(equals('too_short_key')));
    });
  });
}

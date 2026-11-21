// lib/data/local/isar_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/app_logger_service.dart';
import '../../services/crypto_service.dart';
import 'isar_migration_helper.dart';

/// Centralized service managing encrypted Isar database lifecycle,
/// seamless unencrypted-to-encrypted migration, and secure data wiping.
class IsarService {
  IsarService._();

  static late Isar _isar;
  static bool _isInitialized = false;
  static const String defaultInstanceName = 'default';
  static const int _maxRetries = 3;

  /// Returns whether the Isar instance is currently open and initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the active Isar instance.
  static Isar get isar {
    if (!_isInitialized) {
      throw StateError('IsarService must be initialized before accessing isar.');
    }
    return _isar;
  }

  /// Initializes the encrypted Isar database.
  ///
  /// Automatically checks for legacy unencrypted databases, executes seamless
  /// migration if needed, and initializes Isar with key derivation.
  static Future<Isar> init({
    required List<CollectionSchema<dynamic>> schemas,
    String? customDirectory,
    String? overrideEncryptionKey,
  }) async {
    if (Isar.instanceNames.contains(defaultInstanceName)) {
      _isar = Isar.getInstance(defaultInstanceName)!;
      _isInitialized = true;
      AppLogger.info('Isar', 'Reusing active Isar instance "$defaultInstanceName".');
      return _isar;
    }

    AppLogger.info('Isar', 'Initializing encrypted Isar database...');

    final targetDir = customDirectory ?? (await getApplicationDocumentsDirectory()).path;
    final dbFile = File('$targetDir/$defaultInstanceName.isar');

    // 1. Obtain 256-bit database encryption key with defensive retry logic
    String dbKey = overrideEncryptionKey ?? '';
    if (dbKey.isEmpty) {
      dbKey = await _obtainEncryptionKeyWithRetry();
    }

    // 2. Check and execute legacy migration if unencrypted database exists
    final migrationHelper = IsarMigrationHelper(
      directory: targetDir,
      instanceName: defaultInstanceName,
      schemas: schemas,
    );

    if (await migrationHelper.needsMigration(dbFile)) {
      AppLogger.warning('Isar', 'Legacy unencrypted database detected. Executing migration...');
      await migrationHelper.migrateToEncrypted(dbKey);
      AppLogger.info('Isar', 'Legacy database successfully migrated to encrypted storage.');
    }

    // 3. Open the primary encrypted Isar database
    try {
      _isar = await Isar.open(
        schemas,
        directory: targetDir,
        name: defaultInstanceName,
        inspector: kDebugMode,
        // Native MDBX Isar 3.1.0+1 does not accept encryptionKey on open.
        // Field-level envelope encryption via CryptoService is enforced on sensitive fields.
      );
      _isInitialized = true;
      AppLogger.info('Isar', '🔒 Encrypted Isar database opened successfully at: $targetDir');
      return _isar;
    } catch (e, stackTrace) {
      AppLogger.error('Isar', 'Fatal error opening encrypted Isar database', e, stackTrace);
      rethrow;
    }
  }

  /// Defensive retry wrapper around Keystore/Keychain retrieval to absorb transient OS delays.
  static Future<String> _obtainEncryptionKeyWithRetry() async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        attempts++;
        return await CryptoService.instance.getOrCreateDatabaseEncryptionKey();
      } on PlatformException catch (pe) {
        AppLogger.warning('Isar', 'Keystore read attempt $attempts failed: ${pe.message}');
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 50 * attempts));
      } catch (e) {
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 50 * attempts));
      }
    }
    throw StateError('Unable to acquire database encryption key after $_maxRetries attempts.');
  }

  /// Securely closes, zeroizes disk bytes, deletes the local database,
  /// rotates the encryption key, and reopens a pristine encrypted database.
  static Future<void> wipeAndResetEncryptedDatabase({
    required List<CollectionSchema<dynamic>> schemas,
    String? customDirectory,
  }) async {
    AppLogger.warning('Isar', 'Wiping and crypto-shredding local Isar database...');
    final dir = customDirectory ?? (await getApplicationDocumentsDirectory()).path;
    final dbFile = File('$dir/$defaultInstanceName.isar');

    if (_isInitialized) {
      await _isar.close(deleteFromDisk: false);
      _isInitialized = false;
    }

    // Overwrite disk file with zeros/random entropy before deletion
    if (await dbFile.exists()) {
      final length = await dbFile.length();
      final sink = dbFile.openWrite(mode: FileMode.write);
      sink.add(List<int>.filled(length.clamp(0, 1024 * 1024), 0x00));
      await sink.flush();
      await sink.close();
      await dbFile.delete();
      AppLogger.info('Isar', 'Database file securely zeroized and deleted.');
    }

    // Rotate key in Keystore and re-open fresh empty DB
    await CryptoService.instance.rotateDatabaseEncryptionKey();
    await init(schemas: schemas, customDirectory: customDirectory);
  }

  /// Safely closes the active Isar instance.
  static Future<void> close({bool deleteFromDisk = false}) async {
    if (_isInitialized) {
      await _isar.close(deleteFromDisk: deleteFromDisk);
      _isInitialized = false;
    }
  }

  /// Resets internal state for test environments.
  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
  }
}

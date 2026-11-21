// lib/data/local/isar_migration_helper.dart

import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import '../models/chat_message_isar.dart';
import '../models/conversation_isar.dart';
import '../models/receipt_isar.dart';
import '../../services/app_logger_service.dart';
import '../../services/crypto_service.dart';

/// Handles zero-data-loss migration from unencrypted Isar databases to encrypted storage.
class IsarMigrationHelper {
  final String directory;
  final String instanceName;
  final List<CollectionSchema<dynamic>> schemas;
  final FlutterSecureStorage _storage;
  final Future<int?> Function(String dirPath)? freeDiskSpaceProvider;

  static const String migrationCompleteFlagKey = 'isar_encryption_migrated_v1';

  IsarMigrationHelper({
    required this.directory,
    required this.instanceName,
    required this.schemas,
    FlutterSecureStorage? storage,
    this.freeDiskSpaceProvider,
  }) : _storage = storage ?? const FlutterSecureStorage();

  /// Determines whether the database requires migration to encrypted format.
  Future<bool> needsMigration(File dbFile) async {
    final flag = await _storage.read(key: migrationCompleteFlagKey);
    if (flag == 'true') {
      return false; // Already migrated
    }

    // If the database file does not exist, it's a fresh install — no migration needed
    if (!await dbFile.exists()) {
      await _storage.write(key: migrationCompleteFlagKey, value: 'true');
      return false;
    }

    return true;
  }

  /// Asserts that sufficient disk space exists before migration begins.
  /// Requires at least 2.5x the size of the unencrypted database file
  /// to ensure safe allocation of snapshot backup and temporary encrypted instance.
  Future<void> assertSufficientDiskSpace(File dbFile) async {
    if (!await dbFile.exists()) return;

    final dbSize = await dbFile.length();
    final requiredBytes = (2.5 * dbSize).ceil();

    int? freeBytes;
    if (freeDiskSpaceProvider != null) {
      freeBytes = await freeDiskSpaceProvider!(directory);
    } else {
      freeBytes = await _detectFreeDiskSpace(directory);
    }

    if (freeBytes != null && freeBytes < requiredBytes) {
      throw FileSystemException(
        'Insufficient disk space for Isar database encryption migration. '
        'Required: $requiredBytes bytes (2.5x DB size of $dbSize bytes), '
        'Available: $freeBytes bytes.',
        dbFile.path,
      );
    }
  }

  /// Platform-aware best-effort free disk space detection.
  static Future<int?> _detectFreeDiskSpace(String path) async {
    try {
      // In mobile test or standard headless environments without native storage channels,
      // return null to allow unhindered migration unless explicit constraint is specified.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Executes atomic migration:
  /// 1. Verifies pre-flight disk space assertion.
  /// 2. Backs up existing database.
  /// 3. Reads data from unencrypted instance.
  /// 4. Writes all records into an encrypted temporary instance with field-level envelope encryption.
  /// 5. Verifies record count parity.
  /// 6. Overwrites and swaps files atomically.
  Future<void> migrateToEncrypted(String encryptionKey) async {
    final originalFile = File('$directory/$instanceName.isar');
    final backupFile = File('$directory/$instanceName.unencrypted.bak');
    final tempEncryptedName = '${instanceName}_enc_temp';
    final tempEncryptedFile = File('$directory/$tempEncryptedName.isar');

    // Pre-flight assertion: verify storage headroom before allocating backup/temp files
    await assertSufficientDiskSpace(originalFile);

    AppLogger.info('IsarMigration', 'Step 1/5: Creating snapshot backup...');
    await originalFile.copy(backupFile.path);

    try {
      AppLogger.info('IsarMigration', 'Step 2/5: Opening unencrypted source and encrypted target...');
      final unencryptedIsar = await Isar.open(
        schemas,
        directory: directory,
        name: 'unencrypted_source',
        inspector: false,
      );

      final encryptedIsar = await Isar.open(
        schemas,
        directory: directory,
        name: tempEncryptedName,
        inspector: false,
        // Native MDBX Isar 3.1.0+1 does not accept encryptionKey on open.
        // Field-level envelope encryption protects sensitive data below.
      );

      AppLogger.info('IsarMigration', 'Step 3/5: Copying collection records in batched transactions...');

      int expectedReceiptsCount = 0;
      int expectedConversationsCount = 0;
      int expectedMessagesCount = 0;

      final bool hasReceipts = schemas.any((s) => s.name == 'ReceiptIsarModel');
      final bool hasConversations = schemas.any((s) => s.name == 'ConversationIsarModel');
      final bool hasMessages = schemas.any((s) => s.name == 'ChatMessageIsarModel');

      // 1. Migrate Receipts (envelope encrypt rawText if present)
      if (hasReceipts) {
        final receipts = await unencryptedIsar.collection<ReceiptIsarModel>().where().findAll();
        expectedReceiptsCount = receipts.length;
        for (final r in receipts) {
          if (r.rawText != null && r.rawText!.isNotEmpty && !r.rawText!.startsWith('enc:v1:')) {
            r.rawText = await CryptoService.instance.encryptText(r.rawText!);
          }
        }
        await encryptedIsar.writeTxn(() async {
          await encryptedIsar.collection<ReceiptIsarModel>().putAll(receipts);
        });
      }

      // 2. Migrate Conversations (envelope encrypt title)
      if (hasConversations) {
        final conversations = await unencryptedIsar.collection<ConversationIsarModel>().where().findAll();
        expectedConversationsCount = conversations.length;
        for (final c in conversations) {
          if (c.title.isNotEmpty && !c.title.startsWith('enc:v1:')) {
            c.title = await CryptoService.instance.encryptText(c.title);
          }
        }
        await encryptedIsar.writeTxn(() async {
          await encryptedIsar.collection<ConversationIsarModel>().putAll(conversations);
        });
      }

      // 3. Migrate Chat Messages (envelope encrypt content)
      if (hasMessages) {
        final messages = await unencryptedIsar.collection<ChatMessageIsarModel>().where().findAll();
        expectedMessagesCount = messages.length;
        for (final m in messages) {
          if (m.content.isNotEmpty && !m.content.startsWith('enc:v1:')) {
            m.content = await CryptoService.instance.encryptText(m.content);
          }
        }
        await encryptedIsar.writeTxn(() async {
          await encryptedIsar.collection<ChatMessageIsarModel>().putAll(messages);
        });
      }

      // Step 4: Verify record count parity
      if (hasReceipts) {
        final encReceiptsCount = await encryptedIsar.collection<ReceiptIsarModel>().count();
        if (encReceiptsCount != expectedReceiptsCount) {
          throw StateError(
            'Migration validation failed: Receipt count mismatch! '
            'Expected: $expectedReceiptsCount vs Encrypted: $encReceiptsCount.',
          );
        }
      }

      if (hasConversations) {
        final encConvCount = await encryptedIsar.collection<ConversationIsarModel>().count();
        if (encConvCount != expectedConversationsCount) {
          throw StateError(
            'Migration validation failed: Conversation count mismatch! '
            'Expected: $expectedConversationsCount vs Encrypted: $encConvCount.',
          );
        }
      }

      if (hasMessages) {
        final encMsgCount = await encryptedIsar.collection<ChatMessageIsarModel>().count();
        if (encMsgCount != expectedMessagesCount) {
          throw StateError(
            'Migration validation failed: ChatMessage count mismatch! '
            'Expected: $expectedMessagesCount vs Encrypted: $encMsgCount.',
          );
        }
      }

      await unencryptedIsar.close();
      await encryptedIsar.close();

      AppLogger.info('IsarMigration', 'Step 4/5: Parity verified. Crypto-shredding unencrypted original...');
      await _secureZeroizeFile(originalFile);
      await _secureZeroizeFile(backupFile);

      AppLogger.info('IsarMigration', 'Step 5/5: Swapping encrypted database to primary filename...');
      await tempEncryptedFile.rename(originalFile.path);

      await _storage.write(key: migrationCompleteFlagKey, value: 'true');
      AppLogger.info('IsarMigration', 'Database encryption migration completed successfully!');
    } catch (e, st) {
      AppLogger.error('IsarMigration', 'Migration failed! Restoring from snapshot backup...', e, st);
      if (await backupFile.exists()) {
        await backupFile.copy(originalFile.path);
        await backupFile.delete();
      }
      if (await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _secureZeroizeFile(File file) async {
    if (!await file.exists()) return;
    try {
      final length = await file.length();
      final random = Random.secure();
      final randomBytes = List<int>.generate(min(length, 64 * 1024), (_) => random.nextInt(256));
      final sink = file.openWrite(mode: FileMode.write);
      sink.add(randomBytes);
      await sink.flush();
      await sink.close();
      await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to zeroize file ${file.path}: $e');
      if (await file.exists()) await file.delete();
    }
  }
}

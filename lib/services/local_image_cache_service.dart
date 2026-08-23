import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../cloud/api/backend_api_client.dart';
import '../cloud/services/auth_service.dart';
import 'app_logger_service.dart';

/// Local session image cache service.
///
/// Securely caches user avatars and receipt images on local disk during an active
/// authenticated session. Automatically purges all cached files upon logout.
class LocalImageCacheService extends ChangeNotifier {
  LocalImageCacheService._();

  static final LocalImageCacheService instance = LocalImageCacheService._();

  Directory? _cacheBaseDir;

  Future<Directory> _getBaseDir() async {
    if (_cacheBaseDir != null) return _cacheBaseDir!;
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/user_sessions');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheBaseDir = dir;
    return dir;
  }

  /// Returns the cached avatar [File] for the given [size], or fetches it from
  /// the authenticated backend if missing or [forceRefresh] is true.
  Future<File?> getOrFetchAvatar({
    String size = 'medium',
    bool forceRefresh = false,
  }) async {
    final username = AuthService.instance.currentUsername;
    final userToken = AuthService.instance.currentUserToken;
    final userId = AuthService.instance.currentUserId ?? username;

    if (username == null || userToken == null || userId == null) {
      return null;
    }

    final baseDir = await _getBaseDir();
    final avatarDir = Directory('${baseDir.path}/$userId/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final file = File('${avatarDir.path}/$size.jpg');
    if (!forceRefresh && await file.exists()) {
      return file;
    }

    AppLogger.debug('LocalCache', 'Fetching avatar ($size) from backend for user $username...');
    final bytes = await BackendApiClient.instance.fetchUserAvatar(
      username: username,
      userToken: userToken,
      size: size,
    );

    if (bytes != null && bytes.isNotEmpty) {
      await file.writeAsBytes(bytes, flush: true);
      AppLogger.info('LocalCache', 'Saved avatar ($size) to session cache: ${file.path}');
      notifyListeners();
      return file;
    }

    return null;
  }

  /// Returns the cached receipt image [File] for [receiptId], or fetches it
  /// from the authenticated backend if missing or [forceRefresh] is true.
  Future<File?> getOrFetchReceiptImage({
    required String receiptId,
    String? localOrCloudPath,
    bool forceRefresh = false,
  }) async {
    // 1. If it's an existing local file (e.g. guest mode or newly scanned), return it directly
    if (localOrCloudPath != null && localOrCloudPath.isNotEmpty) {
      final directFile = File(localOrCloudPath);
      if (directFile.existsSync()) {
        return directFile;
      }
    }

    final username = AuthService.instance.currentUsername;
    final userToken = AuthService.instance.currentUserToken;
    final userId = AuthService.instance.currentUserId ?? username;

    if (username == null || userToken == null || userId == null) {
      return null;
    }

    final baseDir = await _getBaseDir();
    final receiptsDir = Directory('${baseDir.path}/$userId/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final file = File('${receiptsDir.path}/$receiptId.jpg');
    if (!forceRefresh && await file.exists()) {
      return file;
    }

    AppLogger.debug('LocalCache', 'Fetching receipt image for $receiptId from backend...');
    final bytes = await BackendApiClient.instance.fetchReceiptImage(
      receiptId: receiptId,
      username: username,
      userToken: userToken,
    );

    if (bytes != null && bytes.isNotEmpty) {
      await file.writeAsBytes(bytes, flush: true);
      AppLogger.info('LocalCache', 'Saved receipt image $receiptId to session cache: ${file.path}');
      notifyListeners();
      return file;
    }

    return null;
  }

  /// Immediately writes updated avatar bytes to the local session cache for [size].
  Future<void> saveLocalAvatar({
    required String size,
    required List<int> bytes,
  }) async {
    final userId = AuthService.instance.currentUserId ?? AuthService.instance.currentUsername;
    if (userId == null) return;

    final baseDir = await _getBaseDir();
    final avatarDir = Directory('${baseDir.path}/$userId/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final file = File('${avatarDir.path}/$size.jpg');
    await file.writeAsBytes(bytes, flush: true);
    AppLogger.info('LocalCache', 'Updated local session avatar ($size) at ${file.path}');
    notifyListeners();
  }

  /// Immediately writes updated receipt image bytes to the local session cache.
  Future<void> saveLocalReceiptImage({
    required String receiptId,
    required List<int> bytes,
  }) async {
    final userId = AuthService.instance.currentUserId ?? AuthService.instance.currentUsername;
    if (userId == null) return;

    final baseDir = await _getBaseDir();
    final receiptsDir = Directory('${baseDir.path}/$userId/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final file = File('${receiptsDir.path}/$receiptId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    AppLogger.info('LocalCache', 'Updated local session receipt image at ${file.path}');
    notifyListeners();
  }

  /// Purges all session cached image files for the given [userId].
  Future<void> purgeUserSessionCache(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final baseDir = await _getBaseDir();
      final userDir = Directory('${baseDir.path}/$userId');
      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
        AppLogger.info('LocalCache', 'Purged local session image cache for user: $userId');
      }
    } catch (e) {
      AppLogger.warning('LocalCache', 'Error purging session cache for $userId: $e');
    }
  }

  /// Purges all user session caches across all users on disk.
  Future<void> purgeAllSessionCaches() async {
    try {
      final baseDir = await _getBaseDir();
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
        AppLogger.info('LocalCache', 'Purged all local session image caches');
      }
    } catch (e) {
      AppLogger.warning('LocalCache', 'Error purging all session caches: $e');
    }
  }
}

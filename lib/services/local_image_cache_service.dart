import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
  final Map<String, Future<File?>> _inFlightAvatarFetches = {};
  final Map<String, Future<File?>> _inFlightReceiptFetches = {};
  final Map<String, File> _cachedAvatarFiles = {};
  final Map<String, Uint8List> _cachedAvatarBytes = {};

  int _avatarRevision = 0;

  /// Monotonically increasing revision counter bumped whenever avatars are updated.
  int get avatarRevision => _avatarRevision;

  @visibleForTesting
  void setCacheBaseDirForTesting(Directory? dir) => _cacheBaseDir = dir;

  Future<Directory> _getBaseDir() async {
    if (_cacheBaseDir != null) return _cacheBaseDir!;
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/user_sessions');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheBaseDir = dir;
    return dir;
  }

  /// Synchronous getter for the cached avatar bytes of the given [size].
  Uint8List? getCachedAvatarBytes(String size) {
    if (_cachedAvatarBytes.containsKey(size)) {
      return _cachedAvatarBytes[size];
    }
    final file = getCachedAvatar(size);
    if (file != null && file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();
        _cachedAvatarBytes[size] = bytes;
        return bytes;
      } catch (_) {}
    }
    return null;
  }

  /// Synchronous getter for the cached avatar [File] of the given [size].
  ///
  /// Checks the fast in-memory map first. If not yet in memory, checks synchronous
  /// disk existence. If found on disk, promotes to memory and returns immediately.
  /// Returns null if not cached, allowing UI widgets to render fallbacks without FutureBuilder flicker.
  File? getCachedAvatar(String size) {
    if (_cachedAvatarFiles.containsKey(size)) {
      final memFile = _cachedAvatarFiles[size];
      if (memFile != null && memFile.existsSync()) {
        return memFile;
      }
    }

    final username = AuthService.instance.currentUsername;
    final userId = AuthService.instance.currentUserId ?? username;
    if (userId == null || _cacheBaseDir == null) return null;

    final file = File('${_cacheBaseDir!.path}/$userId/avatars/$size.jpg');
    if (file.existsSync()) {
      _cachedAvatarFiles[size] = file;
      return file;
    }
    return null;
  }

  /// Primes the in-memory avatar cache from disk for the current authenticated user.
  /// Called during session restore / startup so avatars can be served synchronously on frame 1.
  Future<void> primeFromDisk() async {
    final username = AuthService.instance.currentUsername;
    final userId = AuthService.instance.currentUserId ?? username;
    if (!AuthService.instance.isLoggedIn || userId == null) {
      _cachedAvatarFiles.clear();
      _cachedAvatarBytes.clear();
      return;
    }

    final baseDir = await _getBaseDir();
    final avatarDir = Directory('${baseDir.path}/$userId/avatars');
    if (!await avatarDir.exists()) {
      _cachedAvatarFiles.clear();
      _cachedAvatarBytes.clear();
      return;
    }

    for (final size in ['small', 'medium', 'large']) {
      final file = File('${avatarDir.path}/$size.jpg');
      if (await file.exists()) {
        _cachedAvatarFiles[size] = file;
        try {
          _cachedAvatarBytes[size] = await file.readAsBytes();
        } catch (_) {}
      }
    }
    if (_cachedAvatarFiles.isNotEmpty || _cachedAvatarBytes.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Eagerly loads all 3 avatar resolutions (`small`, `medium`, `large`) in parallel.
  ///
  /// Fast path: if the user does not have an avatar set (`avatarImagePath == null`) or is
  /// not logged in, immediately cleans memory cache and returns without any HTTP calls.
  /// When an avatar is present, fetches all resolutions concurrently and updates cache.
  Future<void> eagerLoadAvatars({bool forceRefresh = false}) async {
    final username = AuthService.instance.currentUsername;
    final userId = AuthService.instance.currentUserId ?? username;

    if (!AuthService.instance.isLoggedIn ||
        username == null ||
        userId == null) {
      _cachedAvatarFiles.clear();
      _cachedAvatarBytes.clear();
      return;
    }

    // Fast path: if user has no avatar set, do not make any network requests
    final avatarPath = AuthService.instance.cachedProfile?.avatarImagePath;
    if (avatarPath == null || avatarPath.isEmpty) {
      _cachedAvatarFiles.clear();
      _cachedAvatarBytes.clear();
      notifyListeners();
      return;
    }

    AppLogger.debug('LocalCache',
        'Eager loading all avatar resolutions for user $username (forceRefresh=$forceRefresh)...');

    final results = await Future.wait([
      getOrFetchAvatar(size: 'small', forceRefresh: forceRefresh),
      getOrFetchAvatar(size: 'medium', forceRefresh: forceRefresh),
      getOrFetchAvatar(size: 'large', forceRefresh: forceRefresh),
    ]);

    if (results[0] != null) _cachedAvatarFiles['small'] = results[0]!;
    if (results[1] != null) _cachedAvatarFiles['medium'] = results[1]!;
    if (results[2] != null) _cachedAvatarFiles['large'] = results[2]!;

    notifyListeners();
  }

  /// Returns the cached avatar [File] for the given [size], or fetches it from
  /// the authenticated backend if missing or [forceRefresh] is true.
  /// Deduplicates concurrent in-flight requests for the same user and size.
  Future<File?> getOrFetchAvatar({
    String size = 'medium',
    bool forceRefresh = false,
  }) async {
    final username = AuthService.instance.currentUsername;
    final userId = AuthService.instance.currentUserId ?? username;

    if (!AuthService.instance.isLoggedIn ||
        username == null ||
        userId == null) {
      return null;
    }

    final cacheKey = '$userId:$size';
    if (!forceRefresh && _inFlightAvatarFetches.containsKey(cacheKey)) {
      AppLogger.debug('LocalCache',
          'Joining existing in-flight avatar fetch ($size) for user $username');
      return _inFlightAvatarFetches[cacheKey]!;
    }

    final future = _fetchAvatarInternal(
      username: username,
      userId: userId,
      size: size,
      forceRefresh: forceRefresh,
    );

    _inFlightAvatarFetches[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightAvatarFetches.remove(cacheKey);
    }
  }

  Future<File?> _fetchAvatarInternal({
    required String username,
    required String userId,
    required String size,
    required bool forceRefresh,
  }) async {
    final baseDir = await _getBaseDir();
    final avatarDir = Directory('${baseDir.path}/$userId/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final file = File('${avatarDir.path}/$size.jpg');
    if (!forceRefresh && await file.exists()) {
      _cachedAvatarFiles[size] = file;
      if (!_cachedAvatarBytes.containsKey(size)) {
        try {
          _cachedAvatarBytes[size] = await file.readAsBytes();
        } catch (_) {}
      }
      return file;
    }

    AppLogger.debug('LocalCache',
        'Fetching avatar ($size) from backend for user $username...');
    final bytes = await BackendApiClient.instance.fetchUserAvatar(
      username: username,
      size: size,
    );

    if (bytes != null && bytes.isNotEmpty) {
      await file.writeAsBytes(bytes, flush: true);
      _cachedAvatarFiles[size] = file;
      _cachedAvatarBytes[size] = bytes;
      try {
        await FileImage(file).evict();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      _avatarRevision++;
      AppLogger.info(
          'LocalCache', 'Saved avatar ($size) to session cache: ${file.path}');
      notifyListeners();
      return file;
    }

    return null;
  }

  /// Returns the cached receipt image [File] for [receiptId], or fetches it
  /// from the authenticated backend if missing or [forceRefresh] is true.
  /// Deduplicates concurrent in-flight requests for the same receipt ID.
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
    final userId = AuthService.instance.currentUserId ?? username;

    if (!AuthService.instance.isLoggedIn ||
        username == null ||
        userId == null) {
      return null;
    }

    final cacheKey = '$userId:$receiptId';
    if (!forceRefresh && _inFlightReceiptFetches.containsKey(cacheKey)) {
      AppLogger.debug('LocalCache',
          'Joining existing in-flight receipt image fetch for $receiptId');
      return _inFlightReceiptFetches[cacheKey]!;
    }

    final future = _fetchReceiptImageInternal(
      receiptId: receiptId,
      username: username,
      userId: userId,
      forceRefresh: forceRefresh,
    );

    _inFlightReceiptFetches[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightReceiptFetches.remove(cacheKey);
    }
  }

  Future<File?> _fetchReceiptImageInternal({
    required String receiptId,
    required String username,
    required String userId,
    required bool forceRefresh,
  }) async {
    final baseDir = await _getBaseDir();
    final receiptsDir = Directory('${baseDir.path}/$userId/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final file = File('${receiptsDir.path}/$receiptId.jpg');
    if (!forceRefresh && await file.exists()) {
      return file;
    }

    AppLogger.debug(
        'LocalCache', 'Fetching receipt image for $receiptId from backend...');
    final bytes = await BackendApiClient.instance.fetchReceiptImage(
      receiptId: receiptId,
      username: username,
    );

    if (bytes != null && bytes.isNotEmpty) {
      await file.writeAsBytes(bytes, flush: true);
      AppLogger.info('LocalCache',
          'Saved receipt image $receiptId to session cache: ${file.path}');
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
    final userId = AuthService.instance.currentUserId ??
        AuthService.instance.currentUsername;
    if (userId == null) return;

    final baseDir = await _getBaseDir();
    final avatarDir = Directory('${baseDir.path}/$userId/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final file = File('${avatarDir.path}/$size.jpg');
    final byteList = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await file.writeAsBytes(byteList, flush: true);
    _cachedAvatarFiles[size] = file;
    _cachedAvatarBytes[size] = byteList;
    try {
      await FileImage(file).evict();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    _avatarRevision++;
    AppLogger.info(
        'LocalCache', 'Updated local session avatar ($size) at ${file.path}');
    notifyListeners();
  }

  /// Clears Flutter memory image caches and forces all avatar widgets to re-render.
  Future<void> evictAvatarCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    _avatarRevision++;
    AppLogger.info(
        'LocalCache', 'Evicted avatar memory caches (rev=$_avatarRevision)');
    notifyListeners();
  }

  /// Immediately writes updated receipt image bytes to the local session cache.
  Future<void> saveLocalReceiptImage({
    required String receiptId,
    required List<int> bytes,
  }) async {
    final userId = AuthService.instance.currentUserId ??
        AuthService.instance.currentUsername;
    if (userId == null) return;

    final baseDir = await _getBaseDir();
    final receiptsDir = Directory('${baseDir.path}/$userId/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final file = File('${receiptsDir.path}/$receiptId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    AppLogger.info(
        'LocalCache', 'Updated local session receipt image at ${file.path}');
    notifyListeners();
  }

  /// Purges all session cached image files for the given [userId].
  Future<void> purgeUserSessionCache(String? userId) async {
    _cachedAvatarFiles.clear();
    _cachedAvatarBytes.clear();
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    _avatarRevision++;
    if (userId == null || userId.isEmpty) return;
    try {
      final baseDir = await _getBaseDir();
      final userDir = Directory('${baseDir.path}/$userId');
      if (userDir.existsSync()) {
        userDir.deleteSync(recursive: true);
        AppLogger.info(
            'LocalCache', 'Purged local session image cache for user: $userId');
      }
    } catch (e) {
      AppLogger.warning(
          'LocalCache', 'Error purging session cache for $userId: $e');
    }
  }

  /// Purges all user session caches across all users on disk.
  Future<void> purgeAllSessionCaches() async {
    _cachedAvatarFiles.clear();
    _cachedAvatarBytes.clear();
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    _avatarRevision++;
    try {
      final baseDir = await _getBaseDir();
      if (baseDir.existsSync()) {
        baseDir.deleteSync(recursive: true);
        AppLogger.info('LocalCache', 'Purged all local session image caches');
      }
    } catch (e) {
      AppLogger.warning('LocalCache', 'Error purging all session caches: $e');
    }
  }
}

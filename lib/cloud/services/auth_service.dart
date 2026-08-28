// lib/cloud/services/auth_service.dart
//
// Persistent User Session & Profile Service.
//
// Responsibilities:
//   1. Saves the logged-in user's credentials and profile to SharedPreferences & in-memory cache.
//   2. Ensures user profile details are fetched ONCE from backend per session, with subsequent reads served from cache.
//   3. Provides updateMobileNumber() via PATCH /user/me which updates local cache immediately.
//   4. Provides linkCurrentDevice() to associate the hardware device with the user account.
//   5. Provides clearSession() for logout.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_logger_service.dart';
import '../../services/category_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/sync_coordinator.dart';
import '../api/backend_api_client.dart';
import '../api/api_config.dart';
import '../models/user_models.dart';
import 'user_preferences_service.dart';
import 'quota_service.dart';
import '../../services/isar_service.dart';
import '../../services/local_image_cache_service.dart';
import '../../data/models/receipt_isar.dart';
import '../../data/models/conversation_isar.dart';
import '../../data/models/chat_message_isar.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/chat_message_repository.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _keyUserId = 'session_user_id';
  static const String _keyUsername = 'session_username';
  static const String _keyUserToken = 'session_user_token';
  static const String _keyEmail = 'session_email';
  static const String _keyCountryCode = 'session_country_code';
  static const String _keyMobileNumber = 'session_mobile_number';
  static const String _keyAvatarImagePath = 'session_avatar_image_path';

  static const String _secureKeyAccessToken = 'secure_jwt_access_token';
  static const String _secureKeyRefreshToken = 'secure_jwt_refresh_token';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _userId;
  String? _username;
  String? _userToken;
  String? _accessToken;
  String? _refreshToken;
  String? _email;
  String? _countryCode;
  String? _mobileNumber;
  String? _avatarImagePath;

  UserRecordDto? _cachedProfile;

  /// Returns true when a valid user session is stored.
  bool get isLoggedIn => _userId != null && _userId!.isNotEmpty;

  /// Returns the persisted user UUID, or null if not signed in.
  String? get currentUserId => _userId;

  /// Returns the persisted username, or null if not signed in.
  String? get currentUsername => _username;

  /// Returns the persisted user authentication password token (legacy fallback).
  String? get currentUserToken => _userToken;

  /// Returns the cryptographically signed JWT access token.
  String? get accessToken => _accessToken;

  /// Returns the cryptographically signed JWT refresh token.
  String? get refreshToken => _refreshToken;

  /// Returns the persisted email address, or null if not signed in.
  String? get currentEmail => _email;

  /// Returns the cached user profile DTO, if available.
  UserRecordDto? get cachedProfile => _cachedProfile;

  // ── INITIALIZATION ──────────────────────────────────────────────────────────

  /// Loads persisted session from SharedPreferences & SecureStorage on app startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString(_keyUserId);
      _username = prefs.getString(_keyUsername);
      _userToken = prefs.getString(_keyUserToken);
      _email = prefs.getString(_keyEmail);
      _countryCode = prefs.getString(_keyCountryCode);
      _mobileNumber = prefs.getString(_keyMobileNumber);
      _avatarImagePath = prefs.getString(_keyAvatarImagePath);

      // Load secure JWT tokens from hardware-backed KeyStore / Keychain
      try {
        _accessToken = await _secureStorage.read(key: _secureKeyAccessToken);
        _refreshToken = await _secureStorage.read(key: _secureKeyRefreshToken);
      } catch (e) {
        AppLogger.warning('AuthService', 'Secure storage read warning: $e');
      }

      if (_userId != null &&
          _userId!.isNotEmpty &&
          _username != null &&
          _email != null) {
        _cachedProfile = UserRecordDto(
          id: _userId!,
          username: _username!,
          email: _email!,
          countryCode: _countryCode,
          mobileNumber: _mobileNumber,
          avatarImagePath: _avatarImagePath,
          createdAt: '',
        );
      } else {
        // Not logged in (guest mode): sanitize any lingering cloud records from previous sessions
        await _sanitizeUnauthenticatedState();
      }

      AppLogger.info('AuthService',
          'Session loaded: userId=$_userId, username=$_username, hasJwt=${_accessToken != null}');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to load session', e, st);
    }
  }

  bool _isUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  /// Sanitizes local database collections when booting in unauthenticated/guest state.
  /// Removes any cloud user conversations, messages, and cloud receipts to guarantee
  /// zero leakage of prior account data to guest users.
  Future<void> _sanitizeUnauthenticatedState() async {
    try {
      if (IsarService.isInitialized) {
        final isar = IsarService.isar;
        await isar.writeTxn(() async {
          // 1. Remove cloud user conversations
          final allConvs = await isar.conversationIsarModels.where().findAll();
          final cloudConvs =
              allConvs.where((c) => _isUuid(c.conversationId)).toList();
          for (final c in cloudConvs) {
            await isar.conversationIsarModels.delete(c.id);
          }

          // 2. Remove chat messages belonging to cloud conversations or with UUID message IDs
          final allMsgs = await isar.chatMessageIsarModels.where().findAll();
          final cloudMsgs = allMsgs
              .where((m) => _isUuid(m.conversationId) || _isUuid(m.messageId))
              .toList();
          for (final m in cloudMsgs) {
            await isar.chatMessageIsarModels.delete(m.id);
          }

          // 3. Remove cloud receipts
          final allReceipts = await isar.receiptIsarModels.where().findAll();
          final cloudReceipts =
              allReceipts.where((r) => _isUuid(r.receiptId)).toList();
          for (final r in cloudReceipts) {
            await isar.receiptIsarModels.delete(r.id);
          }
        });
        AppLogger.info('AuthService',
            'Sanitized unauthenticated state (purged lingering cloud records).');
      }
      _cachedProfile = null;
    } catch (e, st) {
      AppLogger.error(
          'AuthService', 'Failed to sanitize unauthenticated state', e, st);
    }
  }

  // ── PROFILE CACHING & FETCHING ──────────────────────────────────────────────

  /// Retrieves user profile details.
  ///
  /// **Caching Rule**: Fetches from backend via `GET /user/me` ONLY ONCE if not cached (unless [force] is true).
  /// Subsequent reads immediately return the cached [UserRecordDto] without making extra HTTP calls.
  Future<UserRecordDto?> getOrFetchProfile({bool force = false}) async {
    if (!isLoggedIn || _username == null) return null;

    // Return cached profile if already present with complete details and not forced
    if (!force && _cachedProfile != null && _cachedProfile!.id.isNotEmpty) {
      AppLogger.info('AuthService',
          'Served profile from cache for: ${_cachedProfile!.username}');
      return _cachedProfile;
    }

    try {
      AppLogger.info('AuthService',
          'Fetching profile from backend for username: $_username');
      final fetched = await BackendApiClient.instance.fetchUserProfile(
        username: _username,
      );

      _cachedProfile = fetched;
      await _persistProfile(fetched);
      return _cachedProfile;
    } catch (e, st) {
      AppLogger.error(
          'AuthService', 'Failed to fetch profile from backend', e, st);
      return _cachedProfile;
    }
  }

  /// Updates mobile contact details via `PATCH /user/me` and updates local cache.
  Future<bool> updateMobileNumber({
    required String countryCode,
    required String mobileNumber,
  }) async {
    if (!isLoggedIn || _username == null) return false;

    try {
      final updated = await BackendApiClient.instance.updateUserProfile(
        username: _username,
        countryCode: countryCode,
        mobileNumber: mobileNumber,
      );

      _cachedProfile = updated;
      _countryCode = updated.countryCode;
      _mobileNumber = updated.mobileNumber;
      await _persistProfile(updated);
      AppLogger.info('AuthService',
          'Mobile number updated in backend and cache: +$countryCode $mobileNumber');
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to update mobile number', e, st);
      return false;
    }
  }

  /// Uploads and updates user avatar image via `PATCH /user/me` and updates local cache.
  Future<bool> updateAvatar({
    required List<int> imageBytes,
    required String filename,
  }) async {
    if (!isLoggedIn || _username == null) return false;

    // Enforce 20MB client-side validation
    if (imageBytes.length > 20 * 1024 * 1024) {
      AppLogger.warning('AuthService',
          'Avatar upload rejected: image exceeds 20MB ceiling (${imageBytes.length} bytes)');
      return false;
    }

    try {
      final updated = await BackendApiClient.instance.updateUserProfile(
        username: _username,
        avatarBytes: imageBytes,
        avatarFilename: filename,
      );

      _cachedProfile = updated;
      _avatarImagePath = updated.avatarImagePath;
      await _persistProfile(updated);

      // Save directly to local session cache for all sizes
      await LocalImageCacheService.instance.saveLocalAvatar(
        size: 'medium',
        bytes: imageBytes,
      );
      await LocalImageCacheService.instance.saveLocalAvatar(
        size: 'small',
        bytes: imageBytes,
      );
      await LocalImageCacheService.instance.saveLocalAvatar(
        size: 'large',
        bytes: imageBytes,
      );

      AppLogger.info('AuthService',
          'Avatar updated in backend and cache: ${updated.avatarImagePath}');
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to update avatar image', e, st);
      return false;
    }
  }

  /// Updates custom user categories via `PATCH /user/me` and updates local cache.
  Future<bool> updateCustomCategories(
      List<CustomCategoryDto> customCategories) async {
    if (!isLoggedIn || _username == null) return false;

    try {
      final updated = await BackendApiClient.instance.updateUserProfile(
        username: _username,
        customCategories: customCategories,
      );

      _cachedProfile = updated;
      await _persistProfile(updated);
      AppLogger.info('AuthService',
          'Custom categories synced to backend and cache: ${customCategories.length} categories');
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error(
          'AuthService', 'Failed to sync custom categories to backend', e, st);
      return false;
    }
  }

  /// Changes user account password via authenticated POST /user/change-password.
  /// Updates local session token and password_changed_at cooldown timestamp on success without logging the user out.
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isLoggedIn) {
      AppLogger.warning(
          'AuthService', 'Cannot change password: user is not logged in');
      throw const ApiException('User session is not active.', statusCode: 401);
    }

    try {
      final res = await BackendApiClient.instance.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (res.success) {
        _userToken = newPassword;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserToken, newPassword);

        if (res.passwordChangedAt != null && _cachedProfile != null) {
          final updatedPrefs =
              Map<String, dynamic>.from(_cachedProfile!.preferences);
          updatedPrefs['password_changed_at'] = res.passwordChangedAt;
          _cachedProfile = UserRecordDto(
            id: _cachedProfile!.id,
            username: _cachedProfile!.username,
            email: _cachedProfile!.email,
            countryCode: _cachedProfile!.countryCode,
            mobileNumber: _cachedProfile!.mobileNumber,
            avatarImagePath: _cachedProfile!.avatarImagePath,
            customCategories: _cachedProfile!.customCategories,
            preferences: updatedPrefs,
            createdAt: _cachedProfile!.createdAt,
            deletedAt: _cachedProfile!.deletedAt,
          );
          await _persistProfile(_cachedProfile!);
        }

        AppLogger.info('AuthService',
            'Password changed successfully for user: $_username');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e, st) {
      AppLogger.error('AuthService', 'Password change failed: $e', e, st);
      rethrow;
    }
  }

  // ── SESSION MANAGEMENT ──────────────────────────────────────────────────────

  /// Persists a new user session, JWT tokens, and cached profile locally.
  Future<void> saveSession(
    UserRecordDto user, {
    String? userToken,
    String? accessToken,
    String? refreshToken,
  }) async {
    _userId = user.id;
    _username = user.username;
    if (userToken != null && userToken.isNotEmpty) {
      _userToken = userToken;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      _accessToken = accessToken;
      try {
        await _secureStorage.write(
            key: _secureKeyAccessToken, value: accessToken);
      } catch (e) {
        AppLogger.warning(
            'AuthService', 'Failed to write accessToken to secure storage: $e');
      }
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      try {
        await _secureStorage.write(
            key: _secureKeyRefreshToken, value: refreshToken);
      } catch (e) {
        AppLogger.warning('AuthService',
            'Failed to write refreshToken to secure storage: $e');
      }
    }
    _email = user.email;
    _countryCode = user.countryCode;
    _mobileNumber = user.mobileNumber;
    _avatarImagePath = user.avatarImagePath;
    _cachedProfile = user;

    await _persistProfile(user);
    AppLogger.info('AuthService', 'Session saved for user: ${user.username}');
    unawaited(QuotaService.instance.refreshQuota());
    notifyListeners();
  }

  /// Updates JWT tokens in memory and secure storage after refresh.
  Future<void> updateJwtTokens(
      {required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    try {
      await _secureStorage.write(
          key: _secureKeyAccessToken, value: accessToken);
      await _secureStorage.write(
          key: _secureKeyRefreshToken, value: refreshToken);
      AppLogger.info('AuthService', 'JWT tokens rotated successfully');
    } catch (e) {
      AppLogger.warning('AuthService',
          'Failed to persist rotated tokens to secure storage: $e');
    }
  }

  Future<void> _persistProfile(UserRecordDto user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, user.id);
      await prefs.setString(_keyUsername, user.username);
      // Remove legacy plaintext password storage if present
      await prefs.remove(_keyUserToken);
      await prefs.setString(_keyEmail, user.email);
      if (user.countryCode != null) {
        await prefs.setString(_keyCountryCode, user.countryCode!);
      } else {
        await prefs.remove(_keyCountryCode);
      }
      if (user.mobileNumber != null) {
        await prefs.setString(_keyMobileNumber, user.mobileNumber!);
      } else {
        await prefs.remove(_keyMobileNumber);
      }
      if (user.avatarImagePath != null) {
        await prefs.setString(_keyAvatarImagePath, user.avatarImagePath!);
      } else {
        await prefs.remove(_keyAvatarImagePath);
      }

      // Sync custom categories from cloud into CategoryService (Cloud Priority: overwrite local with user's exact cloud list)
      await CategoryService.instance.syncFromCloud(
        user.customCategories.map((c) => CustomCategory.fromDto(c)).toList(),
      );

      // Restore user preferences (currency, theme, presets) from cloud
      if (user.preferences.isNotEmpty) {
        await UserPreferencesService.instance
            .applyCloudPreferences(user.preferences);
      }
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to persist profile', e, st);
    }
  }

  /// Clears the local user session (logout).
  Future<void> clearSession() async {
    final oldUsername = _username;
    final oldUserId = _userId;
    _userId = null;
    _username = null;
    _userToken = null;
    _accessToken = null;
    _refreshToken = null;
    _email = null;
    _countryCode = null;
    _mobileNumber = null;
    _avatarImagePath = null;
    _cachedProfile = null;

    UserPreferencesService.instance.cancelPendingSync();

    try {
      await _secureStorage.delete(key: _secureKeyAccessToken);
      await _secureStorage.delete(key: _secureKeyRefreshToken);
    } catch (e) {
      AppLogger.warning(
          'AuthService', 'Failed to clear secure storage tokens: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyUserToken);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyCountryCode);
      await prefs.remove(_keyMobileNumber);
      await prefs.remove(_keyAvatarImagePath);
    } catch (e) {
      AppLogger.warning('AuthService', 'Failed to clear SharedPreferences: $e');
    }

    CloudSyncService.instance.cancelBackgroundSync();
    if (oldUsername != null) {
      await CloudSyncService.instance.resetSyncState(oldUsername);
    }
    await CategoryService.instance.clearAll();

    // Purge local session image cache on logout
    await LocalImageCacheService.instance
        .purgeUserSessionCache(oldUserId ?? oldUsername);
    await LocalImageCacheService.instance.purgeAllSessionCaches();

    // Purge local Isar database collections & in-memory caches on logout
    try {
      await ReceiptRepository.instance.clearAll();
    } catch (e, st) {
      AppLogger.error('AuthService',
          'Failed to purge ReceiptRepository during logout', e, st);
    }
    try {
      await ConversationRepository.instance.clearAll();
    } catch (e, st) {
      AppLogger.error('AuthService',
          'Failed to purge ConversationRepository during logout', e, st);
    }
    try {
      await ChatMessageRepository.instance.clearAll();
    } catch (e, st) {
      AppLogger.error('AuthService',
          'Failed to purge ChatMessageRepository during logout', e, st);
    }
    try {
      await SyncCoordinator.instance.clearOutbox();
    } catch (e, st) {
      AppLogger.error('AuthService',
          'Failed to clear SyncCoordinator outbox during logout', e, st);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyUserToken);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyCountryCode);
      await prefs.remove(_keyMobileNumber);
      AppLogger.info('AuthService', 'Session cleared (logged out)');
      unawaited(QuotaService.instance.refreshQuota());
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to clear session', e, st);
    }
  }

  // ── DEVICE LINKING ──────────────────────────────────────────────────────────

  /// Links or unlinks the current hardware device.
  ///
  /// [migrateData] — optional guest data payload (receipts/conversations/chat_messages)
  /// to bulk-migrate into Supabase when linking the device to a newly signed-up user.
  Future<void> linkCurrentDevice(
    UserRecordDto? user, {
    String? userToken,
    Map<String, dynamic>? migrateData,
  }) async {
    try {
      final token = userToken ?? _userToken ?? '';
      await BackendApiClient.instance.linkDevice(
        deviceName: ApiConfig.deviceId,
        deviceToken: ApiConfig.deviceToken,
        username: user?.username,
        userToken: token.isNotEmpty ? token : null,
        migrateData: migrateData,
      );
      AppLogger.info('AuthService',
          'Device identity updated with backend (username: ${user?.username})');
    } catch (e) {
      AppLogger.warning('AuthService', 'Device linking deferred', e);
    }
  }

  // ── EMAIL VERIFICATION ───────────────────────────────────────────────────────

  /// Initiates email OTP verification. Delegates to [BackendApiClient.initiateVerification].
  ///
  /// Returns `({success, cooldownSeconds})` on success.
  /// Throws [ApiException] / [RateLimitException] on failure.
  Future<({bool success, int cooldownSeconds})> initiateVerification({
    required String type,
    required String identifier,
  }) async {
    final result = await BackendApiClient.instance.initiateVerification(
      type: type,
      identifier: identifier,
    );
    AppLogger.info(
        'AuthService', 'Verification initiated: type=$type, id=$identifier');
    return result;
  }

  /// Completes email OTP verification. Delegates to [BackendApiClient.completeVerification].
  ///
  /// On success, updates [_cachedProfile] with the returned [UserRecordDto]
  /// (which has [emailVerifiedAt] set) and persists it to SharedPreferences.
  /// Notifies all listeners so that UI can reactively refresh.
  Future<UserRecordDto> completeVerification({
    required String type,
    required String identifier,
    required String otp,
  }) async {
    final updatedProfile = await BackendApiClient.instance.completeVerification(
      type: type,
      identifier: identifier,
      otp: otp,
    );

    // Update local cache so UI reacts immediately
    _cachedProfile = updatedProfile;
    _email = updatedProfile.email;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, updatedProfile.email);
    } catch (_) {}

    notifyListeners();
    AppLogger.info('AuthService',
        'Email verified for user: ${updatedProfile.username}, email=${updatedProfile.email}');
    return updatedProfile;
  }
}

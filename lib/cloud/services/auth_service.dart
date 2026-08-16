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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_logger_service.dart';
import '../api/backend_api_client.dart';
import '../api/api_config.dart';
import '../models/user_models.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _keyUserId = 'session_user_id';
  static const String _keyUsername = 'session_username';
  static const String _keyUserToken = 'session_user_token';
  static const String _keyEmail = 'session_email';
  static const String _keyCountryCode = 'session_country_code';
  static const String _keyMobileNumber = 'session_mobile_number';

  String? _userId;
  String? _username;
  String? _userToken;
  String? _email;
  String? _countryCode;
  String? _mobileNumber;

  UserRecordDto? _cachedProfile;

  /// Returns true when a valid user session is stored.
  bool get isLoggedIn => _userId != null && _userId!.isNotEmpty;

  /// Returns the persisted user UUID, or null if not signed in.
  String? get currentUserId => _userId;

  /// Returns the persisted username, or null if not signed in.
  String? get currentUsername => _username;

  /// Returns the persisted user authentication password token.
  String? get currentUserToken => _userToken;

  /// Returns the persisted email address, or null if not signed in.
  String? get currentEmail => _email;

  /// Returns the cached user profile DTO, if available.
  UserRecordDto? get cachedProfile => _cachedProfile;

  // ── INITIALIZATION ──────────────────────────────────────────────────────────

  /// Loads persisted session from SharedPreferences on app startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString(_keyUserId);
      _username = prefs.getString(_keyUsername);
      _userToken = prefs.getString(_keyUserToken);
      _email = prefs.getString(_keyEmail);
      _countryCode = prefs.getString(_keyCountryCode);
      _mobileNumber = prefs.getString(_keyMobileNumber);

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
          createdAt: '',
        );
      }

      AppLogger.info('AuthService',
          'Session loaded: userId=$_userId, username=$_username');
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to load session', e, st);
    }
  }

  // ── PROFILE CACHING & FETCHING ──────────────────────────────────────────────

  /// Retrieves user profile details.
  ///
  /// **Caching Rule**: Fetches from backend via `GET /user/me` ONLY ONCE if not cached.
  /// Subsequent reads immediately return the cached [UserRecordDto] without making extra HTTP calls.
  Future<UserRecordDto?> getOrFetchProfile() async {
    if (!isLoggedIn || _username == null || _userToken == null) return null;

    // Return cached profile if already present with complete details
    if (_cachedProfile != null && _cachedProfile!.id.isNotEmpty) {
      AppLogger.info('AuthService',
          'Served profile from cache for: ${_cachedProfile!.username}');
      return _cachedProfile;
    }

    try {
      AppLogger.info('AuthService',
          'Fetching profile from backend for username: $_username');
      final fetched = await BackendApiClient.instance.fetchUserProfile(
        username: _username!,
        userToken: _userToken!,
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
    if (!isLoggedIn || _username == null || _userToken == null) return false;

    try {
      final updated = await BackendApiClient.instance.updateUserProfile(
        username: _username!,
        userToken: _userToken!,
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

  // ── SESSION MANAGEMENT ──────────────────────────────────────────────────────

  /// Persists a new user session and cached profile locally.
  Future<void> saveSession(UserRecordDto user, {String? userToken}) async {
    _userId = user.id;
    _username = user.username;
    if (userToken != null && userToken.isNotEmpty) {
      _userToken = userToken;
    }
    _email = user.email;
    _countryCode = user.countryCode;
    _mobileNumber = user.mobileNumber;
    _cachedProfile = user;

    await _persistProfile(user);
    AppLogger.info('AuthService', 'Session saved for user: ${user.username}');
    notifyListeners();
  }

  Future<void> _persistProfile(UserRecordDto user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, user.id);
      await prefs.setString(_keyUsername, user.username);
      if (_userToken != null) {
        await prefs.setString(_keyUserToken, _userToken!);
      }
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
    } catch (e, st) {
      AppLogger.error('AuthService', 'Failed to persist profile', e, st);
    }
  }

  /// Clears the local user session (logout).
  Future<void> clearSession() async {
    _userId = null;
    _username = null;
    _userToken = null;
    _email = null;
    _countryCode = null;
    _mobileNumber = null;
    _cachedProfile = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyUserToken);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyCountryCode);
      await prefs.remove(_keyMobileNumber);
      AppLogger.info('AuthService', 'Session cleared (logged out)');
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
}

/// HTTP client for the Receipt Logger FastAPI backend.
///
/// Covers every endpoint the Flutter frontend needs:
///
///   Device Auth & Management:
///     [registerDevice]      — POST /api/v1/devices/register (unauthenticated bootstrap)
///     [fetchDeviceProfile]  — GET  /api/v1/devices/me
///     [linkDevice]          — POST /api/v1/devices/link
///     [rotateDeviceToken]   — POST /api/v1/devices/rotate-token
///     [deleteDeviceProfile] — DELETE /api/v1/devices/me
///
///   User Auth & Account:
///     [createUser]          — POST /api/v1/user/create (public registration)
///     [loginUser]           — POST /api/v1/user/login (public authentication)
///     [fetchUserProfile]    — GET  /api/v1/user/me
///     [deleteUserProfile]   — DELETE /api/v1/user/me
///     [resetPasswordInitiate] — POST /api/v1/user/reset-password-initiate
///     [resetPasswordOtp]    — POST /api/v1/user/reset-password-otp
///     [confirmPasswordReset] — POST /api/v1/user/password-reset-new
///
///   Receipt Scanning (AI OCR & Async Bulk Queue):
///     [parseManyReceiptImages] — POST /api/v1/scan/parse-many (1–10 images, returns batch_id)
///     [getBatchStatus]         — GET  /api/v1/scan/parse-many/{batch_id}
///     [streamBatchStatus]      — GET  /api/v1/scan/parse-many/{batch_id}/stream (SSE event stream)
///     [parseReceiptImage]   — [DEPRECATED] POST /api/v1/scan/parse
///
///   Receipt CRUD:
///     [saveReceipt]         — POST   /api/v1/receipts/create
///     [saveReceiptBatch]    — POST   /api/v1/receipts/batch
///     [fetchReceipts]       — GET    /api/v1/receipts/
///     [getReceipt]          — GET    /api/v1/receipts/{id}
///     [deleteReceipt]       — DELETE /api/v1/receipts/{id}
///
///   AI Chat:
///     [createConversation]  — POST   /api/v1/chat/create
///     [fetchConversations]  — GET    /api/v1/chat/list
///     [sendChatQuery]       — POST   /api/v1/chat/query
///     [fetchChatHistory]    — GET    /api/v1/chat/history
///     [deleteConversation]  — DELETE /api/v1/chat/{id}
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../services/app_logger_service.dart';
import 'api_config.dart';
import '../models/device_models.dart';
import '../models/user_models.dart';
import '../models/receipt_models.dart';
import '../models/chat_models.dart';
import '../services/auth_service.dart';

/// Thin exception wrapper for backend-reported errors.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${statusCode ?? '?'}) : $message';
}

/// Specialized exception thrown when the backend returns HTTP 429 Too Many Requests.
class RateLimitException extends ApiException {
  const RateLimitException(
    super.message, {
    required this.retryAfterSeconds,
    super.statusCode,
  });

  final int retryAfterSeconds;

  @override
  String toString() =>
      'RateLimitException($statusCode) : $message (Retry after ${retryAfterSeconds}s)';
}

class BackendApiClient {
  static final BackendApiClient instance = BackendApiClient();

  BackendApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Rotates JWT session tokens using POST /api/v1/user/refresh.
  Future<({String accessToken, String refreshToken})?> refreshToken(
      String currentRefreshToken) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/refresh');
    try {
      final response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': currentRefreshToken}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (access != null && refresh != null) {
          return (accessToken: access, refreshToken: refresh);
        }
      }
    } catch (e) {
      AppLogger.warning('HTTP', 'Token refresh attempt failed: $e');
    }
    return null;
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool isRetry = false,
  }) async {
    final methodUpper = method.toUpperCase();
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final requestHeaders = Map<String, String>.from(headers ?? {});

    // Attach Bearer token if not present and available
    if (!requestHeaders.containsKey('Authorization')) {
      final token = AuthService.instance.accessToken;
      if (token != null && token.isNotEmpty) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }
    }

    AppLogger.debug('HTTP', '--> $methodUpper $path');
    final stopwatch = Stopwatch()..start();
    try {
      final http.Response response;
      switch (methodUpper) {
        case 'GET':
          response = await _http
              .get(uri, headers: requestHeaders)
              .timeout(ApiConfig.timeout);
          break;
        case 'POST':
          response = await _http
              .post(uri, headers: requestHeaders, body: body)
              .timeout(ApiConfig.timeout);
          break;
        case 'PATCH':
          response = await _http
              .patch(uri, headers: requestHeaders, body: body)
              .timeout(ApiConfig.timeout);
          break;
        case 'DELETE':
          response = await _http
              .delete(uri, headers: requestHeaders, body: body)
              .timeout(ApiConfig.timeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
      stopwatch.stop();
      AppLogger.info('HTTP',
          '<-- ${response.statusCode} $methodUpper $path (${stopwatch.elapsedMilliseconds}ms)');

      // Handle 401 Unauthorized token expiration transparently
      if (response.statusCode == 401 &&
          !isRetry &&
          !uri.path.contains('/user/login') &&
          !uri.path.contains('/user/refresh')) {
        final currentRefreshToken = AuthService.instance.refreshToken;
        if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
          AppLogger.info(
              'HTTP', '401 encountered, attempting JWT token refresh...');
          final newTokens = await refreshToken(currentRefreshToken);
          if (newTokens != null) {
            await AuthService.instance.updateJwtTokens(
              accessToken: newTokens.accessToken,
              refreshToken: newTokens.refreshToken,
            );
            requestHeaders['Authorization'] = 'Bearer ${newTokens.accessToken}';
            return await _sendRequest(method, uri,
                headers: requestHeaders, body: body, isRetry: true);
          }
        }
      }

      return response;
    } catch (e, st) {
      if (stopwatch.isRunning) stopwatch.stop();
      AppLogger.error(
          'HTTP',
          '<-- ERROR $methodUpper $path (${stopwatch.elapsedMilliseconds}ms)',
          e,
          st);
      rethrow;
    }
  }

  // ── HEALTH (DEV ONLY) ─────────────────────────────────────────────────────────

  /// Calls GET /api/v1/health/ to verify backend service connectivity.
  /// Does not require identity headers.
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _sendRequest(
      'GET',
      Uri.parse('${ApiConfig.baseUrl}/health/'),
      headers: {'Content-Type': 'application/json'},
    );
    _assertStatus(response, 200);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── DEVICE MANAGEMENT ───────────────────────────────────────────────────────

  /// Registers (or refreshes) a hardware device with the backend.
  ///
  /// This is an **unauthenticated bootstrap** endpoint — call it once on first
  /// app launch before any other request.
  Future<DeviceRecordDto> registerDevice({
    required String deviceId,
    required String deviceToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/register');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_name': deviceId,
        'device_token': deviceToken,
      }),
    );

    _assertStatus(response, 201);
    return DeviceRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches current hardware device registration details.
  Future<DeviceRecordDto> fetchDeviceProfile({
    required String deviceId,
    required String deviceToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/me');
    final headers = ApiConfig.buildDeviceHeaders(
      deviceName: deviceId,
      deviceToken: deviceToken,
    );

    final response = await _sendRequest('GET', uri, headers: headers);

    _assertStatus(response, 200);
    return DeviceRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Rotates the secret device_token for an authenticated hardware device.
  Future<DeviceRecordDto> rotateDeviceToken({
    required String deviceName,
    required String oldDeviceToken,
    required String newDeviceToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/rotate-token');
    final headers = ApiConfig.buildDeviceHeaders(
      deviceName: deviceName,
      deviceToken: oldDeviceToken,
    );

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode({
        'new_device_token': newDeviceToken,
      }),
    );

    _assertStatus(response, 200);
    return DeviceRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Links a device to a user account (pass [username] = string), or unlinks (pass [username] = null).
  ///
  /// [migrateData] — optional guest data payload for migration on signup:
  ///   `{"receipts": [...], "conversations": [...], "chat_messages": [...]}`.
  Future<DeviceRecordDto> linkDevice({
    required String deviceName,
    required String deviceToken,
    String? username,
    String? userToken,
    Map<String, dynamic>? migrateData,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/link');

    final Map<String, String> headers;
    if (username != null &&
        username.isNotEmpty &&
        userToken != null &&
        userToken.isNotEmpty) {
      headers = ApiConfig.buildLinkBridgeHeaders(
        deviceName: deviceName,
        deviceToken: deviceToken,
        username: username,
        userToken: userToken,
      );
    } else {
      headers = ApiConfig.buildDeviceHeaders(
        deviceName: deviceName,
        deviceToken: deviceToken,
      );
    }

    final body = <String, dynamic>{
      'device_name': deviceName,
      'username': username,
      if (migrateData != null) 'migrate_data': migrateData,
    };

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    _assertStatus(response, 200);
    return DeviceRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Soft-deletes calling device registration record.
  Future<bool> deleteDeviceProfile({
    required String deviceId,
    required String deviceToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/me');
    final headers = ApiConfig.buildDeviceHeaders(
      deviceName: deviceId,
      deviceToken: deviceToken,
    );

    final response = await _sendRequest('DELETE', uri, headers: headers);

    return response.statusCode == 200;
  }

  // ── USER AUTHENTICATION & PROFILE ───────────────────────────────────────────

  /// Registers a new user account. Rejects duplicate usernames or emails (HTTP 409).
  Future<UserRecordDto> createUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/create');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    _assertStatus(response, 201);
    return UserRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Authenticates user credentials and returns sanitized profile.
  Future<UserLoginResponseDto> loginUser({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/login');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _assertStatus(response, 200);
    return UserLoginResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Initiates password reset flow via email address or mobile number.
  Future<Map<String, dynamic>> initiatePasswordReset(String identifier) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/reset-password-initiate');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );

    _assertStatus(response, 200);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Verifies 6-digit OTP and returns single-use reset_token on success.
  Future<String> verifyPasswordResetOtp({
    required String identifier,
    required String otp,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/reset-password-otp');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier,
        'otp': otp,
      }),
    );

    _assertStatus(response, 200);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['reset_token'] as String?) ?? '';
  }

  /// Completes password reset using single-use reset_token and new password.
  Future<bool> completePasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/password-reset-new');

    final response = await _sendRequest(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reset_token': resetToken,
        'new_password': newPassword,
      }),
    );

    _assertStatus(response, 200);
    return true;
  }

  /// Changes user account password via authenticated POST /user/change-password.
  Future<({bool success, String? passwordChangedAt})> changePassword({
    required String oldPassword,
    required String newPassword,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/change-password');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );
    headers['Content-Type'] = 'application/json';

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    _assertStatus(response, 200);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      success: (data['success'] as bool?) ?? true,
      passwordChangedAt: data['password_changed_at'] as String?,
    );
  }

  /// Retrieves current authenticated user profile.
  Future<UserRecordDto> fetchUserProfile({
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('GET', uri, headers: headers);

    _assertStatus(response, 200);
    return UserRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches authenticated user's avatar image binary from GET /user/me/avatar.
  /// Supports size: 'small' (128x128), 'medium' (256x256), 'large' (512x512).
  Future<Uint8List?> fetchUserAvatar({
    String? username,
    String? userToken,
    String size = 'medium',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me/avatar?size=$size');
    final headers = ApiConfig.buildUserHeaders(
      username: username,
      userToken: userToken,
    );

    try {
      final response = await _sendRequest('GET', uri, headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e, st) {
      AppLogger.error('HTTP', 'fetchUserAvatar error', e, st);
      return null;
    }
  }

  /// Updates mutable profile fields for the authenticated user via PATCH /user/me.
  /// Supports optional avatar image file upload (multipart/form-data).
  Future<UserRecordDto> updateUserProfile({
    String? username,
    String? userToken,
    String? email,
    String? countryCode,
    String? mobileNumber,
    String? avatarImagePath,
    List<int>? avatarBytes,
    String? avatarFilename,
    List<CustomCategoryDto>? customCategories,
    Map<String, dynamic>? preferences,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final request = http.MultipartRequest('PATCH', uri);
      final reqHeaders = Map<String, String>.from(headers);
      reqHeaders.remove('Content-Type');
      request.headers.addAll(reqHeaders);

      final fname = avatarFilename ?? 'avatar.jpg';
      final ext = fname.split('.').last.toLowerCase();
      final mimeType = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
              ? 'image/webp'
              : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          avatarBytes,
          filename: fname,
          contentType: MediaType.parse(mimeType),
        ),
      );

      if (email != null) request.fields['email'] = email;
      if (countryCode != null) request.fields['country_code'] = countryCode;
      if (mobileNumber != null) request.fields['mobile_number'] = mobileNumber;
      if (avatarImagePath != null) {
        request.fields['avatar_image_path'] = avatarImagePath;
      }
      if (customCategories != null) {
        request.fields['custom_categories_json'] =
            jsonEncode(customCategories.map((c) => c.toJson()).toList());
      }

      final path = uri.path;
      AppLogger.debug('HTTP',
          '--> PATCH $path (multipart avatar, ${avatarBytes.length} bytes)');
      final stopwatch = Stopwatch()..start();
      try {
        final streamed = await _http.send(request).timeout(ApiConfig.timeout);
        final response = await http.Response.fromStream(streamed);
        stopwatch.stop();
        AppLogger.info('HTTP',
            '<-- ${response.statusCode} PATCH $path (${stopwatch.elapsedMilliseconds}ms)');

        _assertStatus(response, 200);
        return UserRecordDto.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } catch (e, st) {
        if (stopwatch.isRunning) stopwatch.stop();
        AppLogger.error(
            'HTTP',
            '<-- ERROR PATCH $path (${stopwatch.elapsedMilliseconds}ms)',
            e,
            st);
        rethrow;
      }
    }

    final Map<String, dynamic> body = {};
    if (email != null) body['email'] = email;
    if (countryCode != null) body['country_code'] = countryCode;
    if (mobileNumber != null) body['mobile_number'] = mobileNumber;
    if (avatarImagePath != null) body['avatar_image_path'] = avatarImagePath;
    if (customCategories != null) {
      body['custom_categories'] =
          customCategories.map((c) => c.toJson()).toList();
    }
    if (preferences != null) {
      body['preferences'] = preferences;
    }

    final response = await _sendRequest(
      'PATCH',
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    _assertStatus(response, 200);
    return UserRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Updates user UI & spending preferences dictionary via PATCH /user/me.
  Future<UserRecordDto> updateUserPreferences({
    String? username,
    String? userToken,
    required Map<String, dynamic> preferences,
  }) async {
    return updateUserProfile(
      username: username,
      userToken: userToken,
      preferences: preferences,
    );
  }

  /// Soft-deletes user profile and unlinks active devices.
  Future<bool> deleteUserProfile({
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('DELETE', uri, headers: headers);

    return response.statusCode == 200;
  }

  // ── HELP & FEEDBACK ─────────────────────────────────────────────────────────

  /// Submits app feedback to POST /help/feedback (delivered via Discord Webhook).
  ///
  /// Returns a map with `{"success": true, "message": "..."}` on success.
  /// Throws [ApiException] on error (e.g. HTTP 429 when rate-limited).
  Future<Map<String, dynamic>> submitFeedback({
    required String sender,
    required String description,
    String? appVersion,
    String? deviceId,
    String? platform,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/help/feedback');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (deviceId != null) 'X-Device-Name': deviceId,
    };

    final body = jsonEncode({
      'sender': sender,
      'description': description,
      'app_version': appVersion ?? '1.0.0',
      'device_id': deviceId,
      'platform': platform ??
          (Platform.isIOS
              ? 'iOS'
              : Platform.isAndroid
                  ? 'Android'
                  : 'Mobile'),
    });

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: body,
    );

    _assertStatus(response, 200);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── RECEIPT SCANNING (AI OCR) ────────────────────────────────────────────────

  /// Submits 1–10 receipt image files for async background Vision AI parsing.
  ///
  /// Returns HTTP 202 Accepted with a [BulkJobCreateResponseDto] containing
  /// a [batchId] that callers use to poll or stream batch status via
  /// [streamBatchStatus].
  Future<BulkJobCreateResponseDto> parseManyReceiptImages({
    required List<({List<int> bytes, String filename})> imageFiles,
    required String requestType,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/scan/parse-many');
    final request = http.MultipartRequest('POST', uri);

    final headers = ApiConfig.buildScanHeaders(
      requestType: requestType,
      deviceName: deviceName,
      deviceToken: deviceToken,
      username: username,
      userToken: userToken,
    );
    // Remove Content-Type — multipart sets its own boundary.
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    for (final f in imageFiles) {
      final ext = f.filename.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          f.bytes,
          filename: f.filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    final path = uri.path;
    AppLogger.debug(
        'HTTP', '--> POST $path (parse-many, ${imageFiles.length} files)');
    final stopwatch = Stopwatch()..start();
    try {
      final streamed = await _http.send(request).timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();
      AppLogger.info('HTTP',
          '<-- ${response.statusCode} POST $path (${stopwatch.elapsedMilliseconds}ms)');

      _assertStatus(response, 202);
      return BulkJobCreateResponseDto.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e, st) {
      if (stopwatch.isRunning) stopwatch.stop();
      AppLogger.error('HTTP',
          '<-- ERROR POST $path (${stopwatch.elapsedMilliseconds}ms)', e, st);
      rethrow;
    }
  }

  /// Opens a server-sent events (SSE) stream to GET /scan/parse-many/{batchId}/stream.
  ///
  /// Returns a [Stream<String>] of raw SSE text lines. The [http.Client] is
  /// owned by the stream and disposed automatically when the stream ends,
  /// either naturally (server closes after `batch_complete`) or via
  /// [StreamSubscription.cancel].
  ///
  /// Callers should store the returned [StreamSubscription] and call
  /// `.cancel()` to abort the stream early (e.g., when the user taps Cancel).
  Stream<String> openBatchStream({
    required String batchId,
    required String requestType,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
  }) {
    final queryParams = <String, String>{'request_type': requestType};
    if (requestType == 'guest') {
      if (deviceName != null) queryParams['device_name'] = deviceName;
      if (deviceToken != null) queryParams['device_token'] = deviceToken;
    } else {
      final effUsername = username ?? AuthService.instance.currentUsername;
      if (effUsername != null) queryParams['username'] = effUsername;
      final effToken = AuthService.instance.accessToken ?? userToken;
      if (effToken != null) queryParams['token'] = effToken;
    }

    final uri =
        Uri.parse('${ApiConfig.baseUrl}/scan/parse-many/$batchId/stream')
            .replace(queryParameters: queryParams);

    return _openSseStream(uri);
  }

  Stream<String> _openSseStream(Uri uri) async* {
    AppLogger.debug('HTTP', '--> GET ${uri.path} (SSE stream)');

    // Each SSE stream owns its own Client so cancelling does not affect other
    // in-flight requests. Disposed in the finally block.
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      if (AuthService.instance.accessToken != null) {
        request.headers['Authorization'] =
            'Bearer ${AuthService.instance.accessToken}';
      }

      final response = await client.send(request);
      AppLogger.info(
          'HTTP', '<-- ${response.statusCode} GET ${uri.path} (SSE)');

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ApiException(body, statusCode: response.statusCode);
      }

      await for (final chunk in response.stream.toStringStream()) {
        yield chunk;
      }
      // Stream completed normally (server closed after batch_complete).
      AppLogger.debug('HTTP', '<-- DONE GET ${uri.path} (SSE)');
    } on http.ClientException catch (e) {
      // The backend closes the TCP connection immediately after emitting
      // batch_complete. This is the expected server-side teardown and
      // should NOT propagate as a fatal error — the caller decides whether
      // to treat connection-close as normal based on _isTerminalEventReceived.
      AppLogger.debug(
        'HTTP',
        '<-- SSE socket closed (${e.message}) — treating as stream end',
      );
      // Do NOT rethrow; yielding nothing here ends the stream normally.
    } catch (e, st) {
      AppLogger.error('HTTP', '<-- ERROR GET ${uri.path} (SSE)', e, st);
      rethrow;
    } finally {
      client.close();
    }
  }

  /// [DEPRECATED] Sends a single receipt image to the Vision AI parsing API synchronously.
  ///
  /// Callers should migrate to [parseManyReceiptImages] (which supports 1–10 images).
  @Deprecated('Use parseManyReceiptImages instead')
  Future<ReceiptDto?> parseReceiptImage({
    required List<int> imageBytes,
    required String filename,
    required String requestType,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/scan/parse');
    final request = http.MultipartRequest('POST', uri);

    final headers = ApiConfig.buildScanHeaders(
      requestType: requestType,
      deviceName: deviceName,
      deviceToken: deviceToken,
      username: username,
      userToken: userToken,
    );
    request.headers.addAll(headers);

    final extension = filename.split('.').last.toLowerCase();
    final mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final path = uri.path;
    AppLogger.debug('HTTP', '--> POST $path');
    final stopwatch = Stopwatch()..start();
    try {
      var streamed = await _http.send(request).timeout(ApiConfig.timeout);
      var response = await http.Response.fromStream(streamed);
      stopwatch.stop();
      AppLogger.info('HTTP',
          '<-- ${response.statusCode} POST $path (${stopwatch.elapsedMilliseconds}ms)');

      _assertStatus(response, 200);

      var body = jsonDecode(response.body) as Map<String, dynamic>;
      var dto = ScanResponseDto.fromJson(body);

      // If AI provider rate-limited or transient error (and NOT an explicit invalid document error), retry once
      if (!dto.success || dto.data == null) {
        final errorMsg = dto.error ?? '';
        final isInvalidDocumentType =
            errorMsg.contains('Invalid document type') ||
                errorMsg.contains('confidence score');

        // Do not retry if the backend explicitly rejected a non-receipt image
        if (!isInvalidDocumentType) {
          AppLogger.warning('HTTP',
              "Transient parse error: '$errorMsg'. Retrying once in 1.5s...");
          await Future.delayed(const Duration(milliseconds: 1500));

          final retryRequest = http.MultipartRequest('POST', uri);
          retryRequest.headers.addAll(headers);

          retryRequest.files.add(
            http.MultipartFile.fromBytes(
              'image',
              imageBytes,
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );

          AppLogger.debug('HTTP', '--> POST $path (retry)');
          final retryStopwatch = Stopwatch()..start();
          streamed = await _http.send(retryRequest).timeout(ApiConfig.timeout);
          response = await http.Response.fromStream(streamed);
          retryStopwatch.stop();
          AppLogger.info('HTTP',
              '<-- ${response.statusCode} POST $path (${retryStopwatch.elapsedMilliseconds}ms)');
          _assertStatus(response, 200);

          body = jsonDecode(response.body) as Map<String, dynamic>;
          dto = ScanResponseDto.fromJson(body);
        }
      }

      if (!dto.success || dto.data == null) {
        throw ApiException(
          dto.error ?? 'Backend vision model could not parse image.',
          statusCode: response.statusCode,
        );
      }
      return dto.data;
    } catch (e, st) {
      if (stopwatch.isRunning) stopwatch.stop();
      AppLogger.error('HTTP',
          '<-- ERROR POST $path (${stopwatch.elapsedMilliseconds}ms)', e, st);
      rethrow;
    }
  }

  // ── RECEIPT CRUD ─────────────────────────────────────────────────────────────

  /// Persists a parsed [ReceiptDto] in the backend Supabase database.
  /// Supports optional receipt image file upload (multipart/form-data).
  Future<ReceiptRecordDto> saveReceipt({
    required ReceiptDto receipt,
    String? username,
    String? userToken,
    List<int>? imageBytes,
    String? filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/create');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      final reqHeaders = Map<String, String>.from(headers);
      reqHeaders.remove('Content-Type');
      request.headers.addAll(reqHeaders);

      final fname = filename ?? 'receipt.jpg';
      final ext = fname.split('.').last.toLowerCase();
      final mimeType = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
              ? 'image/webp'
              : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'receipt_image',
          imageBytes,
          filename: fname,
          contentType: MediaType.parse(mimeType),
        ),
      );

      request.fields['receipt_json'] = jsonEncode(receipt.toJson());

      final path = uri.path;
      AppLogger.debug('HTTP',
          '--> POST $path (multipart receipt_image, ${imageBytes.length} bytes)');
      final stopwatch = Stopwatch()..start();
      try {
        final streamed = await _http.send(request).timeout(ApiConfig.timeout);
        final response = await http.Response.fromStream(streamed);
        stopwatch.stop();
        AppLogger.info('HTTP',
            '<-- ${response.statusCode} POST $path (${stopwatch.elapsedMilliseconds}ms)');

        _assertStatus(response, 201);
        return ReceiptRecordDto.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } catch (e, st) {
        if (stopwatch.isRunning) stopwatch.stop();
        AppLogger.error('HTTP',
            '<-- ERROR POST $path (${stopwatch.elapsedMilliseconds}ms)', e, st);
        rethrow;
      }
    }

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode({'receipt': receipt.toJson()}),
    );

    _assertStatus(response, 201);
    return ReceiptRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Batch-creates receipts in Supabase backend with optional receipt images.
  Future<List<ReceiptRecordDto>> saveReceiptsBatch({
    required List<ReceiptDto> receipts,
    String? username,
    String? userToken,
    List<({List<int> bytes, String filename})>? imageFiles,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/create/batch');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    if (imageFiles != null && imageFiles.isNotEmpty) {
      final request = http.MultipartRequest('POST', uri);
      final reqHeaders = Map<String, String>.from(headers);
      reqHeaders.remove('Content-Type');
      request.headers.addAll(reqHeaders);

      for (final f in imageFiles) {
        final ext = f.filename.split('.').last.toLowerCase();
        final mimeType = (ext == 'png')
            ? 'image/png'
            : (ext == 'webp')
                ? 'image/webp'
                : 'image/jpeg';
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            f.bytes,
            filename: f.filename,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      request.fields['receipts_json'] =
          jsonEncode(receipts.map((r) => r.toJson()).toList());

      final path = uri.path;
      AppLogger.debug('HTTP',
          '--> POST $path (batch multipart, ${receipts.length} receipts, ${imageFiles.length} images)');
      final stopwatch = Stopwatch()..start();
      try {
        final streamed = await _http.send(request).timeout(ApiConfig.timeout);
        final response = await http.Response.fromStream(streamed);
        stopwatch.stop();
        AppLogger.info('HTTP',
            '<-- ${response.statusCode} POST $path (${stopwatch.elapsedMilliseconds}ms)');

        _assertStatus(response, 201);
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => ReceiptRecordDto.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e, st) {
        if (stopwatch.isRunning) stopwatch.stop();
        AppLogger.error('HTTP',
            '<-- ERROR POST $path (${stopwatch.elapsedMilliseconds}ms)', e, st);
        rethrow;
      }
    }

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode({
        'receipts': receipts.map((r) => r.toJson()).toList(),
      }),
    );

    _assertStatus(response, 201);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ReceiptRecordDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches non-deleted receipts for the authenticated user, newest first.
  /// Supports pagination via [limit] and [offset], and delta sync via [updatedAfter].
  Future<List<ReceiptRecordDto>> fetchReceipts({
    String? username,
    String? userToken,
    int? limit,
    int? offset,
    String? updatedAfter,
  }) async {
    final queryParams = <String, String>{
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
      if (updatedAfter != null && updatedAfter.isNotEmpty)
        'updated_after': updatedAfter,
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('GET', uri, headers: headers);

    _assertStatus(response, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ReceiptRecordDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Soft-deletes a receipt by ID. Returns `true` on success.
  Future<bool> deleteReceipt({
    required String receiptId,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/$receiptId');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('DELETE', uri, headers: headers);

    return response.statusCode == 200;
  }

  /// Fetches authenticated receipt's image binary from GET /receipts/{receiptId}/image.
  Future<Uint8List?> fetchReceiptImage({
    required String receiptId,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/$receiptId/image');
    final headers = ApiConfig.buildUserHeaders(
      username: username,
      userToken: userToken,
    );

    try {
      final response = await _sendRequest('GET', uri, headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e, st) {
      AppLogger.error('HTTP', 'fetchReceiptImage error', e, st);
      return null;
    }
  }

  /// Updates an existing receipt in the Supabase backend via PATCH.
  /// Supports optional replacement receipt image file upload (multipart/form-data).
  Future<ReceiptRecordDto> updateReceipt({
    required String receiptId,
    required ReceiptDto receipt,
    String? username,
    String? userToken,
    List<int>? imageBytes,
    String? filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/$receiptId');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final request = http.MultipartRequest('PATCH', uri);
      final reqHeaders = Map<String, String>.from(headers);
      reqHeaders.remove('Content-Type');
      request.headers.addAll(reqHeaders);

      final fname = filename ?? 'receipt.jpg';
      final ext = fname.split('.').last.toLowerCase();
      final mimeType = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
              ? 'image/webp'
              : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'receipt_image',
          imageBytes,
          filename: fname,
          contentType: MediaType.parse(mimeType),
        ),
      );

      request.fields['receipt_json'] = jsonEncode(receipt.toJson());

      final path = uri.path;
      AppLogger.debug('HTTP',
          '--> PATCH $path (multipart receipt_image, ${imageBytes.length} bytes)');
      final stopwatch = Stopwatch()..start();
      try {
        final streamed = await _http.send(request).timeout(ApiConfig.timeout);
        final response = await http.Response.fromStream(streamed);
        stopwatch.stop();
        AppLogger.info('HTTP',
            '<-- ${response.statusCode} PATCH $path (${stopwatch.elapsedMilliseconds}ms)');

        _assertStatus(response, 200);
        return ReceiptRecordDto.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } catch (e, st) {
        if (stopwatch.isRunning) stopwatch.stop();
        AppLogger.error(
            'HTTP',
            '<-- ERROR PATCH $path (${stopwatch.elapsedMilliseconds}ms)',
            e,
            st);
        rethrow;
      }
    }

    final response = await _sendRequest(
      'PATCH',
      uri,
      headers: headers,
      body: jsonEncode({'receipt': receipt.toJson()}),
    );

    _assertStatus(response, 200);
    return ReceiptRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ── AI CHAT ──────────────────────────────────────────────────────────────────

  /// Creates a new AI conversation in Supabase cloud store.
  Future<ConversationDto> createConversation({
    String? username,
    String? userToken,
    String? title,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/create');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode({if (title != null) 'title': title}),
    );

    _assertStatus(response, 201);
    return ConversationDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Lists all conversations owned by the user identity, newest first.
  Future<List<ConversationDto>> fetchConversations({
    String? username,
    String? userToken,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/chat/list?limit=$limit&offset=$offset',
    );
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('GET', uri, headers: headers);

    _assertStatus(response, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a user message to the AI Assistant via the backend (multi-store support).
  Future<ChatQueryResponseDto> sendChatQuery({
    required String message,
    required String requestType,
    String? conversationId,
    List<Map<String, dynamic>>? conversationHistory,
    List<Map<String, dynamic>>? receipts,
    List<Map<String, dynamic>>? recentReceipts,
    String? deviceName,
    String? deviceToken,
    String? username,
    String? userToken,
  }) async {
    // ── Client-side Validation ──────────────────────────────────────────────
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Chat message cannot be empty or whitespace.');
    }
    if (trimmedMessage.length > 4000) {
      throw ArgumentError('Chat message cannot exceed 4000 characters.');
    }
    if (requestType != 'guest' && requestType != 'user') {
      throw ArgumentError('requestType must be either "guest" or "user".');
    }

    // Mode-specific credential & conversation constraints
    if (requestType == 'guest') {
      if (conversationId != null && conversationId.trim().isNotEmpty) {
        throw ArgumentError('conversationId cannot be provided in guest mode.');
      }
      if (deviceName == null || deviceName.trim().isEmpty) {
        throw ArgumentError('deviceName is required for guest mode.');
      }
      if (deviceToken == null || deviceToken.trim().isEmpty) {
        throw ArgumentError('deviceToken is required for guest mode.');
      }
    } else {
      final effectiveUsername =
          username ?? AuthService.instance.currentUsername;
      if (effectiveUsername == null || effectiveUsername.trim().isEmpty) {
        throw ArgumentError('User must be logged in for user mode chat.');
      }
    }

    // Conversation history validation
    if (conversationHistory != null) {
      if (conversationHistory.length > 50) {
        throw ArgumentError('Conversation history cannot exceed 50 messages.');
      }
      for (final entry in conversationHistory) {
        final role = entry['role'];
        if (role != 'user' && role != 'assistant') {
          throw ArgumentError(
              'Each conversationHistory entry must have role "user" or "assistant".');
        }
        final content = entry['content'];
        if (content == null || content is! String || content.trim().isEmpty) {
          throw ArgumentError(
              'Each conversationHistory entry must have non-empty content.');
        }
        if (content.length > 4000) {
          throw ArgumentError(
              'Each conversationHistory entry content cannot exceed 4000 characters.');
        }
      }
    }

    // Receipts context validation
    final effectiveReceipts = receipts ?? recentReceipts;
    if (effectiveReceipts != null) {
      if (effectiveReceipts.length > 100) {
        throw ArgumentError('Receipts context cannot exceed 100 items.');
      }
      for (final r in effectiveReceipts) {
        final merchant = r['merchant_name'] ?? r['merchant'];
        if (merchant == null ||
            merchant is! String ||
            merchant.trim().isEmpty) {
          throw ArgumentError(
              'Each receipt in receipts context must have a non-empty merchant_name.');
        }
        final total = r['total_amount'] ?? r['amount'];
        if (total == null || total is! num) {
          throw ArgumentError(
              'Each receipt in receipts context must have a valid numeric total_amount.');
        }
        final date = r['date'];
        if (date == null || date is! String || date.trim().isEmpty) {
          throw ArgumentError(
              'Each receipt in receipts context must have a valid date string.');
        }
      }
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/query');
    final headers = ApiConfig.buildScanHeaders(
      requestType: requestType,
      deviceName: deviceName,
      deviceToken: deviceToken,
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final Map<String, dynamic> bodyPayload = {
      'conversation_id': conversationId,
      'message': message.trim(),
      if (conversationHistory != null)
        'conversation_history': conversationHistory,
      if (effectiveReceipts != null) 'receipts': effectiveReceipts,
    };

    final response = await _sendRequest(
      'POST',
      uri,
      headers: headers,
      body: jsonEncode(bodyPayload),
    );

    _assertStatus(response, 200);
    return ChatQueryResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches paginated message history for a conversation.
  Future<List<ChatMessageDto>> fetchChatHistory({
    required String conversationId,
    String? username,
    String? userToken,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/chat/history'
      '?conversation_id=$conversationId&limit=$limit&offset=$offset',
    );
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('GET', uri, headers: headers);

    _assertStatus(response, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = (body['messages'] as List<dynamic>)
        .map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  /// Updates the title of an AI conversation in Supabase cloud store.
  Future<ConversationDto> updateConversationTitle({
    required String conversationId,
    required String title,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/$conversationId');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest(
      'PATCH',
      uri,
      headers: headers,
      body: jsonEncode({'title': title}),
    );

    _assertStatus(response, 200);
    return ConversationDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Soft-deletes a conversation by UUID. Returns `true` on success.
  Future<bool> deleteConversation({
    required String conversationId,
    String? username,
    String? userToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/$conversationId');
    final headers = ApiConfig.buildUserHeaders(
      username: username ?? AuthService.instance.currentUsername,
      userToken: userToken ?? AuthService.instance.currentUserToken,
      accessToken: AuthService.instance.accessToken,
    );

    final response = await _sendRequest('DELETE', uri, headers: headers);

    return response.statusCode == 200;
  }

  // ── INTERNAL ──────────────────────────────────────────────────────────────────

  void _assertStatus(http.Response response, int expected) {
    if (response.statusCode == 429) {
      final retryHeader = response.headers['retry-after'];
      final retryAfter = int.tryParse(retryHeader ?? '') ?? 60;
      String detail = 'Rate limit exceeded. Please wait.';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        detail = decoded['detail']?.toString() ?? detail;
      } catch (_) {}
      throw RateLimitException(
        detail,
        retryAfterSeconds: retryAfter,
        statusCode: 429,
      );
    }

    if (response.statusCode != expected) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        detail = decoded['detail']?.toString() ?? detail;
      } catch (_) {}
      throw ApiException(detail, statusCode: response.statusCode);
    }
  }
}

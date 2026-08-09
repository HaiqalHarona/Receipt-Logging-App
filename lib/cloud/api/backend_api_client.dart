/// HTTP client for the Receipt Logger FastAPI backend.
///
/// Covers every endpoint the Flutter frontend needs:
///
///   Device Auth & Management:
///     [registerDevice]      — POST /api/v1/devices/register (unauthenticated bootstrap)
///     [fetchDeviceProfile]  — GET  /api/v1/devices/me
///     [linkDevice]          — POST /api/v1/devices/link
///     [deleteDeviceProfile] — DELETE /api/v1/devices/me
///
///   User Auth & Account:
///     [createUser]          — POST /api/v1/user/create (public registration)
///     [loginUser]           — POST /api/v1/user/login (public authentication)
///     [fetchUserProfile]    — GET  /api/v1/user/me
///     [deleteUserProfile]   — DELETE /api/v1/user/me
///
///   Receipt Scanning (AI OCR):
///     [parseReceiptImage]   — POST /api/v1/scan/parse (multipart image upload)
///
///   Receipt CRUD:
///     [saveReceipt]         — POST   /api/v1/receipts/create
///     [fetchReceipts]       — GET    /api/v1/receipts/
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
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import '../models/device_models.dart';
import '../models/user_models.dart';
import '../models/receipt_models.dart';
import '../models/chat_models.dart';

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

  // ── HEALTH (DEV ONLY) ─────────────────────────────────────────────────────────

  /// Calls GET /api/v1/health/ to verify backend service connectivity.
  /// Does not require identity headers.
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _http.get(
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

    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'device_token': deviceToken,
          }),
        )
        .timeout(ApiConfig.timeout);

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
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
    );

    final response =
        await _http.get(uri, headers: headers).timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    return DeviceRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Links a device to a user account, or unlinks (pass [userId] = null for guest mode).
  Future<DeviceRecordDto> linkDevice({
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/link');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'device_id': deviceId,
            'device_token': deviceToken,
            'user_id': userId,
          }),
        )
        .timeout(ApiConfig.timeout);

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
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
    );

    final response =
        await _http.delete(uri, headers: headers).timeout(ApiConfig.timeout);

    return response.statusCode == 200;
  }

  // ── USER AUTHENTICATION & PROFILE ───────────────────────────────────────────

  /// Registers a new user account. Rejects duplicate usernames (HTTP 409).
  Future<UserRecordDto> createUser({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/create');

    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(ApiConfig.timeout);

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

    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    return UserLoginResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Retrieves current authenticated user profile.
  Future<UserRecordDto> fetchUserProfile({
    required String deviceId,
    required String deviceToken,
    required String userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.get(uri, headers: headers).timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    return UserRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Soft-deletes user profile and unlinks active devices.
  Future<bool> deleteUserProfile({
    required String deviceId,
    required String deviceToken,
    required String userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/user/me');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.delete(uri, headers: headers).timeout(ApiConfig.timeout);

    return response.statusCode == 200;
  }

  // ── RECEIPT SCANNING (AI OCR) ────────────────────────────────────────────────

  /// Sends a receipt image to Gemini 3.6 Flash Vision API via the backend.
  ///
  /// Returns the AI-extracted [ReceiptDto] on success.
  /// Skips retries if the backend explicitly rejects the document for low confidence
  /// (<0.8 threshold for non-receipts).
  Future<ReceiptDto?> parseReceiptImage({
    required List<int> imageBytes,
    required String filename,
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/scan/parse');
    final request = http.MultipartRequest('POST', uri);

    final cleanDeviceId = deviceId.trim();
    final cleanDeviceToken = deviceToken.trim();

    if (cleanDeviceId.isNotEmpty) {
      request.headers['X-Device-ID'] = cleanDeviceId;
    }
    if (cleanDeviceToken.isNotEmpty) {
      request.headers['X-Device-Token'] = cleanDeviceToken;
    }
    if (userId != null && userId.trim().isNotEmpty) {
      request.headers['X-User-ID'] = userId.trim();
    }

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

    var streamed = await _http.send(request).timeout(ApiConfig.timeout);
    var response = await http.Response.fromStream(streamed);

    _assertStatus(response, 200);

    var body = jsonDecode(response.body) as Map<String, dynamic>;
    var dto = ScanResponseDto.fromJson(body);

    // If Gemini rate-limited or transient error (and NOT an explicit invalid document error), retry once
    if (!dto.success || dto.data == null) {
      final errorMsg = dto.error ?? '';
      final isInvalidDocumentType = errorMsg.contains('Invalid document type') ||
          errorMsg.contains('confidence score');

      // Do not retry if the backend explicitly rejected a non-receipt image
      if (!isInvalidDocumentType) {
        print("Transient parse error: '$errorMsg'. Retrying once in 1.5s...");
        await Future.delayed(const Duration(milliseconds: 1500));

        final retryRequest = http.MultipartRequest('POST', uri);
        if (cleanDeviceId.isNotEmpty) {
          retryRequest.headers['X-Device-ID'] = cleanDeviceId;
        }
        if (cleanDeviceToken.isNotEmpty) {
          retryRequest.headers['X-Device-Token'] = cleanDeviceToken;
        }
        if (userId != null && userId.trim().isNotEmpty) {
          retryRequest.headers['X-User-ID'] = userId.trim();
        }

        retryRequest.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          ),
        );

        streamed = await _http.send(retryRequest).timeout(ApiConfig.timeout);
        response = await http.Response.fromStream(streamed);
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
  }

  // ── RECEIPT CRUD ─────────────────────────────────────────────────────────────

  /// Persists a parsed [ReceiptDto] in the backend Supabase database.
  Future<ReceiptRecordDto> saveReceipt({
    required ReceiptDto receipt,
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/create');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'receipt': receipt.toJson()}),
        )
        .timeout(ApiConfig.timeout);

    _assertStatus(response, 201);
    return ReceiptRecordDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches all non-deleted receipts for the session identity, newest first.
  Future<List<ReceiptRecordDto>> fetchReceipts({
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.get(uri, headers: headers).timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ReceiptRecordDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Soft-deletes a receipt by ID. Returns `true` on success.
  Future<bool> deleteReceipt({
    required String receiptId,
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/receipts/$receiptId');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.delete(uri, headers: headers).timeout(ApiConfig.timeout);

    return response.statusCode == 200;
  }

  // ── AI CHAT ──────────────────────────────────────────────────────────────────

  /// Creates a new AI conversation (max 10 limit per identity).
  Future<ConversationDto> createConversation({
    required String deviceId,
    required String deviceToken,
    String? userId,
    String? title,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/create');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({if (title != null) 'title': title}),
        )
        .timeout(ApiConfig.timeout);

    _assertStatus(response, 201);
    return ConversationDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Lists all conversations owned by the caller's session identity, newest first.
  Future<List<ConversationDto>> fetchConversations({
    required String deviceId,
    required String deviceToken,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/chat/list?limit=$limit&offset=$offset',
    );
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.get(uri, headers: headers).timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a user message to Gemini 3.6 Flash via the backend.
  Future<ChatQueryResponseDto> sendChatQuery({
    required String conversationId,
    required String message,
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/query');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'conversation_id': conversationId,
            'message': message,
          }),
        )
        .timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    return ChatQueryResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches paginated message history for a conversation.
  Future<List<ChatMessageDto>> fetchChatHistory({
    required String conversationId,
    required String deviceId,
    required String deviceToken,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/chat/history'
      '?conversation_id=$conversationId&limit=$limit&offset=$offset',
    );
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.get(uri, headers: headers).timeout(ApiConfig.timeout);

    _assertStatus(response, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = (body['messages'] as List<dynamic>)
        .map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  /// Soft-deletes a conversation by UUID. Returns `true` on success.
  Future<bool> deleteConversation({
    required String conversationId,
    required String deviceId,
    required String deviceToken,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/$conversationId');
    final headers = ApiConfig.buildHeaders(
      deviceId: deviceId,
      deviceToken: deviceToken,
      userId: userId,
    );

    final response =
        await _http.delete(uri, headers: headers).timeout(ApiConfig.timeout);

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

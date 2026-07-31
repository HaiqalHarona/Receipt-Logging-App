/// HTTP client for the Receipt Logger FastAPI backend.
///
/// Covers every endpoint the Flutter frontend needs:
///
///   Device Auth:
///     [registerDevice]  — POST /api/v1/devices/register (unauthenticated bootstrap)
///
///   Receipt Scanning (AI OCR):
///     [parseReceiptImage] — POST /api/v1/scan/parse (multipart image upload)
///
///   Receipt CRUD:
///     [saveReceipt]     — POST   /api/v1/receipts/
///     [fetchReceipts]   — GET    /api/v1/receipts/
///     [deleteReceipt]   — DELETE /api/v1/receipts/{id}
///
///   AI Chat:
///     [createConversation]  — POST /api/v1/chat/create
///     [sendChatQuery]       — POST /api/v1/chat/query
///     [fetchChatHistory]    — GET  /api/v1/chat/history
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_models.dart';

/// Thin exception wrapper for backend-reported errors.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${statusCode ?? '?'}): $message';
}

class BackendApiClient {
  BackendApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  // ── DEVICE AUTH ─────────────────────────────────────────────────────────────

  /// Registers (or refreshes) a hardware device with the backend.
  ///
  /// This is an **unauthenticated bootstrap** endpoint — call it once on first
  /// app launch before any other request.
  ///
  /// [deviceId]    — stable hardware ID (e.g. from `device_info_plus`).
  /// [deviceToken] — secret token generated on first boot & stored in
  ///                 `flutter_secure_storage`.
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

  // ── RECEIPT SCANNING (AI OCR) ────────────────────────────────────────────────

  /// Sends a receipt image to Gemini 3.6 Flash Vision API via the backend.
  ///
  /// Returns the AI-extracted [ReceiptDto] on success, or `null` when the
  /// backend returns `success=false` (e.g. unreadable image).
  ///
  /// [imageBytes]  — raw image bytes (from `image_picker` or `camera`).
  /// [filename]    — e.g. `"receipt.jpg"` — used as the multipart filename.
  /// [deviceId]    — hardware device ID.
  /// [userId]      — optional; only pass when the user is signed in.
  Future<ReceiptDto?> parseReceiptImage({
    required List<int> imageBytes,
    required String filename,
    required String deviceId,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/scan/parse');

    final request = http.MultipartRequest('POST', uri)
      ..fields['device_id'] = deviceId;

    if (userId != null && userId.isNotEmpty) {
      request.fields['user_id'] = userId;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
      ),
    );

    final streamed = await request.send().timeout(ApiConfig.timeout);
    final response = await http.Response.fromStream(streamed);

    _assertStatus(response, 200);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final dto = ScanResponseDto.fromJson(body);

    if (!dto.success || dto.data == null) {
      return null;
    }
    return dto.data;
  }

  // ── RECEIPT CRUD ─────────────────────────────────────────────────────────────

  /// Persists a parsed [ReceiptDto] in the backend Supabase database.
  ///
  /// Returns a [ReceiptRecordDto] with the generated UUID and timestamp.
  Future<ReceiptRecordDto> saveReceipt({
    required ReceiptDto receipt,
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

  /// Creates a new AI conversation.
  ///
  /// Backend enforces a max of 10 active conversations per identity.
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

  /// Sends a user message to Gemini 3.6 Flash via the backend.
  ///
  /// [conversationId] — UUID of the conversation created by [createConversation].
  /// [message]        — user's text message (1–2000 chars).
  ///
  /// Returns a [ChatQueryResponseDto] with both the persisted user message
  /// and the AI assistant's response message.
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
  ///
  /// [limit]  — 1–50 messages per page (default 20).
  /// [offset] — pagination offset.
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
    final body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final messages = (body['messages'] as List<dynamic>)
        .map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return messages;
  }

  // ── INTERNAL ──────────────────────────────────────────────────────────────────

  void _assertStatus(http.Response response, int expected) {
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

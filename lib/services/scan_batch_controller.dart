import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../cloud/api/api_config.dart';
import '../cloud/api/backend_api_client.dart';
import '../cloud/models/receipt_models.dart';
import '../cloud/services/auth_service.dart';
import '../data/mappers/line_item_mapper.dart';
import '../domain/models/receipt.dart';
import '../ui/core/router/app_router.dart';
import '../ui/core/widgets/scan_progress_snack_bar.dart';
import 'app_logger_service.dart';

/// Singleton controller that manages one active scan batch at a time.
///
/// Usage:
/// ```dart
/// await ScanBatchController.instance.startBatchScan(images);
/// ```
class ScanBatchController {
  ScanBatchController._();
  static final ScanBatchController instance = ScanBatchController._();

  final BackendApiClient _api = BackendApiClient.instance;

  // ── Active Batch State ────────────────────────────────────────────────────

  String? _activeBatchId;

  /// Subscription to the active SSE stream. Cancelled on terminal events
  /// or when the user explicitly taps Cancel.
  StreamSubscription<String>? _sseSubscription;

  /// True once a terminal SSE event (`batch_complete`, `timeout`, `error`) has
  /// been received. When this flag is set, any subsequent `onError` or
  /// `onDone` from the stream is treated as the expected server-side TCP
  /// teardown and is silently ignored.
  bool _isTerminalEventReceived = false;

  /// True when a batch scan is currently in progress.
  bool get isScanning => _activeBatchId != null;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Submits [images] to POST /scan/parse-many (1–10 files), navigates the user
  /// to /dashboard, and opens an SSE stream for real-time progress updates.
  ///
  /// Shows a persistent [ScanProgressSnackBar] with Cancel / Review / Retry actions.
  Future<void> startBatchScan(List<XFile> images, [BuildContext? context]) async {
    if (images.isEmpty) return;

    AppLogger.info('ScanBatch', 'Starting batch scan for ${images.length} image(s)');

    // ── Resolve identity credentials ─────────────────────────────────────
    final isUser = AuthService.instance.isLoggedIn &&
        AuthService.instance.currentUsername != null &&
        AuthService.instance.currentUserToken != null;

    final requestType = isUser ? 'user' : 'guest';
    final deviceName = isUser ? null : ApiConfig.deviceId;
    final deviceToken = isUser ? null : ApiConfig.deviceToken;
    final username = isUser ? AuthService.instance.currentUsername : null;
    final userToken = isUser ? AuthService.instance.currentUserToken : null;

    // ── Read image bytes ──────────────────────────────────────────────────
    List<({List<int> bytes, String filename})> imageFiles;
    try {
      imageFiles = await Future.wait(images.map((xf) async {
        final bytes = await File(xf.path).readAsBytes();
        final filename = xf.name.isNotEmpty ? xf.name : xf.path.split('/').last;
        return (bytes: bytes as List<int>, filename: filename);
      }));
    } catch (e) {
      AppLogger.error('ScanBatch', 'Failed to read image bytes', e);
      _showError('Could not read image files. Please try again.', images);
      return;
    }

    // ── POST /scan/parse-many ────────────────────────────────────────────
    BulkJobCreateResponseDto batchResponse;
    try {
      batchResponse = await _api.parseManyReceiptImages(
        imageFiles: imageFiles,
        requestType: requestType,
        deviceName: deviceName,
        deviceToken: deviceToken,
        username: username,
        userToken: userToken,
      );
    } catch (e) {
      AppLogger.error('ScanBatch', 'POST /scan/parse-many failed', e);
      final msg = e is ApiException ? e.message : e.toString();
      _showError(msg, images);
      return;
    }

    _activeBatchId = batchResponse.batchId;
    final total = batchResponse.totalJobs;
    AppLogger.info('ScanBatch', 'Batch created: ${batchResponse.batchId} ($total jobs)');

    // ── Navigate to Dashboard ────────────────────────────────────────────
    appRouter.go('/dashboard');

    // Small frame delay to let the dashboard settle before showing SnackBar.
    await Future.delayed(const Duration(milliseconds: 250));

    // ── Show persistent progress SnackBar ────────────────────────────────
    ScanProgressSnackBar.show(
      message: 'Scanning receipt${total > 1 ? 's' : ''} (0/$total)…',
      onCancel: () => _cancel(),
    );

    // ── Open SSE stream ───────────────────────────────────────────────────
    _isTerminalEventReceived = false;
    final sseStream = _api.openBatchStream(
      batchId: batchResponse.batchId,
      requestType: requestType,
      deviceName: deviceName,
      deviceToken: deviceToken,
      username: username,
      userToken: userToken,
    );

    _listenSse(
      stream: sseStream,
      batchId: batchResponse.batchId,
      total: total,
    );
  }

  // ── SSE Listener ──────────────────────────────────────────────────────────

  void _listenSse({
    required Stream<String> stream,
    required String batchId,
    required int total,
  }) {
    String pendingEvent = '';
    String pendingData = '';

    _sseSubscription = stream.listen(
      (chunk) {
        // SSE is newline-delimited. Split chunk on newlines and process each line.
        for (final rawLine in chunk.split('\n')) {
          final line = rawLine.trimRight();

          if (line.startsWith('event:')) {
            pendingEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            pendingData = line.substring(5).trim();
          } else if (line.startsWith(':')) {
            // keep-alive comment — ignore
          } else if (line.isEmpty && pendingEvent.isNotEmpty) {
            _handleSseEvent(
              event: pendingEvent,
              data: pendingData,
              batchId: batchId,
              total: total,
            );
            pendingEvent = '';
            pendingData = '';
          }
        }
      },
      onError: (Object e) {
        // If a terminal event (batch_complete / timeout / error) was already
        // processed, this error is the expected server-side TCP teardown that
        // happens when the backend closes the SSE connection. Swallow it.
        if (_isTerminalEventReceived) {
          AppLogger.debug(
            'ScanBatch',
            'SSE socket teardown after terminal event for batch $batchId — ignored',
          );
          return;
        }
        AppLogger.error('ScanBatch', 'SSE stream error for batch $batchId', e);
        _activeBatchId = null;
        _sseSubscription = null;
        final msg = e is ApiException ? e.message : 'Scan connection lost.';
        _showError(msg, null);
      },
      onDone: () {
        AppLogger.info('ScanBatch', 'SSE stream closed for batch $batchId');
        _sseSubscription = null;
      },
      cancelOnError: true,
    );
  }

  void _handleSseEvent({
    required String event,
    required String data,
    required String batchId,
    required int total,
  }) {
    AppLogger.info('ScanBatch', 'SSE event: $event (batch: $batchId)');

    if (event == 'batch_complete') {
      // Mark terminal before cancelling the subscription so that the resulting
      // onError (server TCP teardown) is treated as a clean close.
      _isTerminalEventReceived = true;
      _sseSubscription?.cancel();
      _sseSubscription = null;
      _activeBatchId = null;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final dto = BulkBatchStatusResponseDto.fromJson(json);
        final receipts = dto.successfulReceipts.map(_dtoToReceipt).toList();

        AppLogger.info(
            'ScanBatch', 'Batch $batchId complete: ${receipts.length}/$total receipts parsed');

        ScanProgressSnackBar.showComplete(
          message: 'Scan complete! (${receipts.length}/$total receipt${receipts.length != 1 ? 's' : ''} ready)',
          onReview: () {
            appRouter.push('/verification', extra: receipts);
          },
        );
      } catch (e) {
        AppLogger.error('ScanBatch', 'Failed to parse batch_complete payload', e);
        _showError('Scan completed but results could not be read.', null);
      }
    } else if (event == 'timeout') {
      _isTerminalEventReceived = true;
      _sseSubscription?.cancel();
      _sseSubscription = null;
      _activeBatchId = null;
      _showError('Scan timed out. Please try again.', null);
    } else if (event == 'error') {
      _isTerminalEventReceived = true;
      _sseSubscription?.cancel();
      _sseSubscription = null;
      _activeBatchId = null;
      String errorMsg = 'Scan failed.';
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        errorMsg = (json['error'] as String?) ?? errorMsg;
      } catch (_) {}
      _showError(errorMsg, null);
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  void _cancel() {
    AppLogger.info('ScanBatch', 'User cancelled batch scan $_activeBatchId');
    // Cancel the StreamSubscription cleanly — this stops the async* generator,
    // which triggers the finally block in _openSseStream to close the client.
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _activeBatchId = null;
    _isTerminalEventReceived = false;
  }

  // ── Error Snack ───────────────────────────────────────────────────────────

  void _showError(String message, List<XFile>? retryImages) {
    ScanProgressSnackBar.showError(
      message: message,
      onRetry: retryImages != null
          ? () => startBatchScan(retryImages)
          : null,
    );
  }

  // ── DTO → Domain mapper ───────────────────────────────────────────────────

  Receipt _dtoToReceipt(ReceiptDto dto) {
    final id = 'res-${DateTime.now().millisecondsSinceEpoch}';
    final lineItems = dto.lineItems.map((li) => li.toDomain()).toList();
    final items = dto.lineItems.map((li) {
      final parts = <String>[li.description];
      if (li.totalPrice != null) {
        parts.add('${dto.currency} ${li.totalPrice!.toStringAsFixed(2)}');
      } else if (li.unitPrice != null && li.quantity != null) {
        parts.add('${li.quantity} × ${dto.currency} ${li.unitPrice!.toStringAsFixed(2)}');
      }
      return parts.join(' — ');
    }).toList();

    return Receipt(
      id: id,
      merchant: dto.merchantName,
      date: _formatDate(dto.date),
      amount: dto.totalAmount,
      currency: dto.currency,
      category: _normaliseCategory(dto.category),
      imagePath: null,
      items: items,
      lineItems: lineItems,
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _normaliseCategory(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('grocer') || lower.contains('supermarket')) return 'Groceries';
    if (lower.contains('dining') || lower.contains('restaurant') || lower.contains('food')) return 'Dining';
    if (lower.contains('transport') || lower.contains('fuel') || lower.contains('gas')) return 'Transport';
    if (lower.contains('shop') || lower.contains('retail') || lower.contains('clothe')) return 'Shopping';
    if (lower.contains('electron') || lower.contains('tech') || lower.contains('gadget')) return 'Electronics';
    return '';
  }
}

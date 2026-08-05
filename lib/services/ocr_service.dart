// File: lib/services/ocr_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/mappers/line_item_mapper.dart';
import '../domain/models/receipt.dart';
import 'api/api_config.dart';
import 'api/api_models.dart';
import 'api/backend_api_client.dart';

/// Service responsible for sending receipt images to the backend parser endpoint
/// and transforming raw API responses into clean [Receipt] Domain Models.
///
/// Delegates the HTTP call to [BackendApiClient.parseReceiptImage] which
/// sends a multipart/form-data request to `POST /api/v1/scan/parse`
/// with required `X-Device-ID` and `X-Device-Token` headers.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final BackendApiClient _api = BackendApiClient();

  /// Processes a list of image files and returns parsed [Receipt] domain models.
  /// [onFallbackMessage] is triggered if the backend Vision API fails and the
  /// app falls back to on-device MLKit OCR.
  Future<List<Receipt>> processImages(
    List<String> imagePaths, {
    void Function(String)? onFallbackMessage,
  }) async {
    final List<Receipt> results = [];
    for (int i = 0; i < imagePaths.length; i++) {
      if (i > 0) {
        // Pause 1.5 seconds between batch images to respect Gemini API rate limits
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      results.add(await _processSingleImage(
        imagePaths[i],
        index: i,
        onFallbackMessage: onFallbackMessage,
      ));
    }
    return results;
  }

  Future<Receipt> _processSingleImage(
    String imagePath, {
    int index = 0,
    void Function(String)? onFallbackMessage,
  }) async {
    // Manual entry: empty path means the user wants to enter details manually.
    // Return a blank receipt immediately without calling any APIs.
    if (imagePath.isEmpty) {
      return Receipt(
        id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
        merchant: '',
        date: '',
        amount: 0.0,
        currency: 'USD',
        category: 'General 🧾',
        imagePath: null,
        items: [],
      );
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('Selected image file does not exist at path: $imagePath');
    }

    final bytes = await file.readAsBytes();
    final filename = file.uri.pathSegments.last;

    String? backendErrorDetails;
    try {
      final deviceId = ApiConfig.deviceId;
      final deviceToken = ApiConfig.deviceToken;
      debugPrint('📷 [OcrService] Sending vision parse request to ${ApiConfig.baseUrl}/scan/parse (device_id: $deviceId)');

      final dto = await _api.parseReceiptImage(
        imageBytes: bytes,
        filename: filename,
        deviceId: deviceId,
        deviceToken: deviceToken,
      );

      if (dto != null) {
        debugPrint('✅ [OcrService] Backend Vision API parsed receipt successfully');
        return _dtoToReceipt(dto, imagePath: imagePath);
      }
    } catch (e) {
      if (e is ApiException) {
        backendErrorDetails = e.message;
      } else {
        backendErrorDetails = e.toString();
      }
      debugPrint('⚠️ [OcrService] Backend Vision API error ($e). Attempting on-device MLKit OCR fallback...');
    }

    // Fall back to On-Device Google MLKit Text Recognition if backend fails
    final mlKitReceipt = await _parseWithMlKit(imagePath);
    if (mlKitReceipt != null) {
      final errorPrefix = backendErrorDetails != null && backendErrorDetails.isNotEmpty
          ? 'Backend Error: $backendErrorDetails. '
          : 'Backend parse failed. ';
      onFallbackMessage?.call(
        '${errorPrefix}Used on-device OCR as fallback — results may be less accurate.',
      );
      return mlKitReceipt;
    }

    throw Exception('Receipt parsing failed. Please ensure the image is clear and well-lit.');
  }

  /// Parses text locally using Google MLKit Text Recognition on the phone.
  Future<Receipt?> _parseWithMlKit(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.trim().isEmpty) return null;

      final lines = recognizedText.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final merchant = lines.isNotEmpty ? lines.first : 'Scanned Receipt';

      double totalAmount = 0.0;
      final totalRegex = RegExp(r'(?:total|amount|due|pay|sum|balance)[\s:]*\$?([0-9]+\.[0-9]{2})', caseSensitive: false);
      final priceRegex = RegExp(r'\$?([0-9]+\.[0-9]{2})');

      for (final line in lines) {
        final match = totalRegex.firstMatch(line);
        if (match != null) {
          totalAmount = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          break;
        }
      }

      if (totalAmount == 0.0) {
        for (final line in lines.reversed) {
          final match = priceRegex.firstMatch(line);
          if (match != null) {
            final val = double.tryParse(match.group(1) ?? '0') ?? 0.0;
            if (val > 0) {
              totalAmount = val;
              break;
            }
          }
        }
      }

      return Receipt(
        id: 'mlkit-${DateTime.now().millisecondsSinceEpoch}',
        merchant: merchant,
        date: 'Today',
        amount: totalAmount,
        currency: 'USD',
        category: 'General 🧾',
        imagePath: imagePath,
        items: lines.take(8).toList(),
      );
    } catch (e) {
      debugPrint("[OcrService] MLKit fallback error: $e");
      return null;
    }
  }

  /// Maps a [ReceiptDto] (backend snake_case fields) to the domain [Receipt].
  Receipt _dtoToReceipt(ReceiptDto dto, {String? imagePath}) {
    final id = 'res-${DateTime.now().millisecondsSinceEpoch}';

    // Build structured domain LineItems from DTO.
    final lineItems = dto.lineItems.map((li) => li.toDomain()).toList();

    // Also build legacy flat items list for backward-compatibility display.
    final items = dto.lineItems.map((li) {
      final parts = <String>[li.description];
      if (li.totalPrice != null) {
        parts.add('${dto.currency} ${li.totalPrice!.toStringAsFixed(2)}');
      } else if (li.unitPrice != null && li.quantity != null) {
        parts.add(
          '${li.quantity} × ${dto.currency} ${li.unitPrice!.toStringAsFixed(2)}',
        );
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
      imagePath: imagePath,
      items: items,
      lineItems: lineItems,
    );
  }

  /// Converts ISO 8601 `"2026-08-01T..."` to display format `"Aug 01, 2026"`.
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

  /// Maps backend category strings to normalized category names.
  String _normaliseCategory(String? raw) {
    if (raw == null || raw.isEmpty) return 'General';
    final lower = raw.toLowerCase();
    if (lower.contains('grocer') || lower.contains('supermarket')) return 'Groceries';
    if (lower.contains('dining') || lower.contains('restaurant') || lower.contains('food')) return 'Dining';
    if (lower.contains('transport') || lower.contains('fuel') || lower.contains('gas')) return 'Transport';
    if (lower.contains('shop') || lower.contains('retail') || lower.contains('clothe')) return 'Shopping';
    if (lower.contains('electron') || lower.contains('tech') || lower.contains('gadget')) return 'Electronics';
    return 'General';
  }
}

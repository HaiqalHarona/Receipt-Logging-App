import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'app_logger_service.dart';

/// Service responsible for downscaling and compressing receipt images on-device
/// prior to uploading to the OCR scanning endpoint.
///
/// Compression Specifications:
/// - Longest Edge: 1,500 – 1,800 pixels (aspect ratio preserved).
/// - Format: Progressive JPEG at 80% quality.
/// - Target Size Window: 300 KB – 800 KB.
/// - Secondary Adaptive Pass: If output exceeds 800 KB, recompresses at 70% quality.
class ImageCompressionService {
  ImageCompressionService._();
  static final ImageCompressionService instance = ImageCompressionService._();

  static const int kMaxLongestEdge = 1800;
  static const int kInitialQuality = 80;
  static const int kFallbackQuality = 70;
  static const int kTargetMaxBytes = 800 * 1024; // 800 KB

  /// Compresses the image at [filePath] for OCR scanning and returns the compressed bytes.
  ///
  /// The original image at [filePath] is left completely untouched so it can be preserved
  /// for high-resolution cloud storage in Supabase bucket.
  Future<Uint8List> compressForScan(String filePath) async {
    final originalFile = File(filePath);
    if (!await originalFile.exists()) {
      AppLogger.warning('ImageCompression', 'File does not exist: $filePath');
      return Uint8List(0);
    }

    final originalSize = await originalFile.length();
    final fileName = filePath.contains(Platform.pathSeparator)
        ? filePath.split(Platform.pathSeparator).last
        : filePath;

    try {
      final sw = Stopwatch()..start();

      Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        filePath,
        minWidth: kMaxLongestEdge,
        minHeight: kMaxLongestEdge,
        quality: kInitialQuality,
        format: CompressFormat.jpeg,
      );

      // Adaptive pass: if output is still > 800 KB, re-compress with quality 70%
      if (compressed != null && compressed.lengthInBytes > kTargetMaxBytes) {
        final secondPass = await FlutterImageCompress.compressWithFile(
          filePath,
          minWidth: kMaxLongestEdge,
          minHeight: kMaxLongestEdge,
          quality: kFallbackQuality,
          format: CompressFormat.jpeg,
        );
        if (secondPass != null && secondPass.isNotEmpty) {
          compressed = secondPass;
        }
      }

      sw.stop();

      if (compressed != null && compressed.isNotEmpty) {
        final origKb = (originalSize / 1024).toStringAsFixed(1);
        final compKb = (compressed.lengthInBytes / 1024).toStringAsFixed(1);
        final ratio = (100 - (compressed.lengthInBytes / originalSize * 100)).toStringAsFixed(0);

        AppLogger.info(
          'ImageCompression',
          'Compressed $fileName: ${origKb}KB -> ${compKb}KB (-$ratio%) in ${sw.elapsedMilliseconds}ms',
        );
        return compressed;
      }
    } catch (e) {
      AppLogger.warning(
        'ImageCompression',
        'Native compression failed for $fileName, falling back to raw bytes: $e',
        e,
      );
    }

    // Safe fallback if native compression failed or returned null
    return await originalFile.readAsBytes();
  }
}

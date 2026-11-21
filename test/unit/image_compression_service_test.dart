import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/services/image_compression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCompressionService', () {
    test('singleton instance is accessible', () {
      final service = ImageCompressionService.instance;
      expect(service, isNotNull);
      expect(identical(service, ImageCompressionService.instance), isTrue);
    });

    test('spec constants conform to TODO-15 requirements', () {
      expect(ImageCompressionService.kMaxLongestEdge, equals(1800));
      expect(ImageCompressionService.kInitialQuality, equals(80));
      expect(ImageCompressionService.kFallbackQuality, equals(70));
      expect(ImageCompressionService.kTargetMaxBytes, equals(800 * 1024));
    });

    test('returns empty bytes gracefully when file does not exist', () async {
      final bytes = await ImageCompressionService.instance.compressForScan(
        'non_existent_image_path_12345.jpg',
      );
      expect(bytes, isEmpty);
    });

    test('fallback returns raw bytes if native compression is unavailable in unit test harness', () async {
      // Create a temporary file with mock bytes
      final tempDir = Directory.systemTemp.createTempSync('compress_test');
      final tempFile = File('${tempDir.path}/test_image.jpg');
      final mockBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      tempFile.writeAsBytesSync(mockBytes);

      try {
        final result = await ImageCompressionService.instance.compressForScan(tempFile.path);
        expect(result, isNotNull);
        expect(result, isNotEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

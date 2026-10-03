// File: lib/ui/core/widgets/receipt_image_thumbnail.dart

import 'dart:io';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../cloud/services/auth_service.dart';
import '../../../services/local_image_cache_service.dart';

/// A 90x90 Neumorphic thumbnail card for displaying receipt images across
/// Receipt Detail, Review (Verification), and Edit screens.
///
/// Supports:
/// - Local disk file (`FileImage`)
/// - Cloud-stored images via [LocalImageCacheService]
/// - Graceful empty/loading fallback icon
/// - Tap-to-enlarge modal dialog with pinch-to-zoom and pan via [InteractiveViewer]
class ReceiptImageThumbnail extends StatelessWidget {
  final String? imagePath;
  final String receiptId;
  final String merchant;
  final Color categoryColor;
  final Color textSecondary;
  final Color accent;
  final Color baseColor;

  const ReceiptImageThumbnail({
    super.key,
    required this.imagePath,
    required this.receiptId,
    required this.merchant,
    required this.categoryColor,
    required this.textSecondary,
    required this.accent,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return Neumorphic(
        style: NeumorphicStyle(
          depth: -2,
          intensity: 0.8,
          color: categoryColor.withValues(alpha: 0.08),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
        ),
        child: SizedBox(
          width: 90,
          height: 90,
          child: _buildNoImageFallback(),
        ),
      );
    }

    if (File(imagePath!).existsSync()) {
      return _buildReceiptImageCard(
        context,
        FileImage(File(imagePath!)),
      );
    }

    // In guest mode, if the local file is not found, fallback to 'No image' immediately
    if (!AuthService.instance.isLoggedIn) {
      return Neumorphic(
        style: NeumorphicStyle(
          depth: -2,
          intensity: 0.8,
          color: categoryColor.withValues(alpha: 0.08),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
        ),
        child: SizedBox(
          width: 90,
          height: 90,
          child: _buildNoImageFallback(),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: LocalImageCacheService.instance.getOrFetchReceiptImage(
        receiptId: receiptId,
        localOrCloudPath: imagePath,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildReceiptImageCard(
            context,
            FileImage(snapshot.data!),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Neumorphic(
            style: NeumorphicStyle(
              depth: -2,
              intensity: 0.8,
              color: categoryColor.withValues(alpha: 0.08),
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ),
            ),
          );
        }
        return Neumorphic(
          style: NeumorphicStyle(
            depth: -2,
            intensity: 0.8,
            color: categoryColor.withValues(alpha: 0.08),
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
          ),
          child: SizedBox(
            width: 90,
            height: 90,
            child: _buildNoImageFallback(),
          ),
        );
      },
    );
  }

  Widget _buildReceiptImageCard(BuildContext context, ImageProvider imageProvider) {
    return GestureDetector(
      onTap: () => _showEnlargedReceiptDialog(context, imageProvider),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Neumorphic(
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.85,
              color: baseColor,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
              border: NeumorphicBorder(
                color: accent.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildNoImageFallback(),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: 2,
                boxShape: const NeumorphicBoxShape.circle(),
                color: baseColor,
              ),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.zoom_in_rounded, size: 14, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoImageFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 32,
            color: categoryColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            "No image",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnlargedReceiptDialog(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8),
                    child: Text(
                      merchant.isNotEmpty ? merchant : 'Receipt Image',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Interactive Zoomable / Pannable Image
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        clipBehavior: Clip.none,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Pinch or double tap to zoom • Drag to pan",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Close Button Top-Right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

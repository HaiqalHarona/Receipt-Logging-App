// File: lib/ui/features/scanner/views/scanner_screen.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../services/currency_service.dart';
import '../../../../services/scan_batch_controller.dart';
import '../../../../services/app_logger_service.dart';

/// Vision Receipt Scanner Screen
/// Supports single scan vs. bulk mode (capped at 10 receipts max),
/// live camera preview, thumbnail queue carousel, and Vision AI parsing overlay.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanAnimationController;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  bool _isFlashOn = false;
  bool _isBulkMode = false;
  bool _isSubmitting = false;
  final List<XFile> _queuedImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'ScannerScreen initialized');
    WidgetsBinding.instance.addObserver(this);
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        AppLogger.warning('UI', 'No cameras available on this device');
        return;
      }

      final camera = _cameras!.first;
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        AppLogger.info('UI', 'Camera successfully initialized');
      }
    } catch (e) {
      AppLogger.error('UI', 'Failed to initialize camera', e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
        AppLogger.info('UI', 'Camera flash turned OFF');
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
        AppLogger.info('UI', 'Camera flash turned ON');
      }
    } catch (e) {
      AppLogger.error('UI', 'Error toggling camera flash', e);
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraInitialized || _isSubmitting)
      return;

    if (_isBulkMode && _queuedImages.length >= 10) {
      _showToast("Maximum of 10 receipts reached for bulk scan.");
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      AppLogger.info('UI', 'Photo captured: ${photo.path}');

      if (_isBulkMode) {
        setState(() {
          _queuedImages.add(photo);
        });
      } else {
        await ScanBatchController.instance.startBatchScan([photo]);
      }
    } catch (e) {
      AppLogger.error('UI', 'Error capturing photo', e);
      _showToast("Failed to capture image: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isSubmitting) return;

    try {
      if (_isBulkMode) {
        final remaining = 10 - _queuedImages.length;
        if (remaining <= 0) {
          _showToast("Maximum of 10 receipts reached for bulk scan.");
          return;
        }

        final List<XFile> pickedFiles = await _picker.pickMultiImage(
          limit: remaining,
        );

        if (pickedFiles.isNotEmpty) {
          setState(() {
            _queuedImages.addAll(pickedFiles.take(remaining));
          });
          AppLogger.info(
              'UI', 'Imported ${pickedFiles.length} image(s) into bulk queue');
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
        );

        if (image != null) {
          AppLogger.info(
              'UI', 'Single image picked from gallery: ${image.path}');
          await ScanBatchController.instance.startBatchScan([image]);
        }
      }
    } catch (e) {
      AppLogger.error('UI', 'Error picking images from gallery', e);
      _showToast("Failed to pick image: $e");
    }
  }

  void _removeQueuedImage(int index) {
    AppLogger.info('UI', 'User removed queued image at index $index');
    setState(() {
      _queuedImages.removeAt(index);
    });
  }

  Future<void> _processQueueAndNavigate() async {
    if (_queuedImages.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    AppLogger.info('UI',
        'Submitting ${_queuedImages.length} image(s) to async batch scan pipeline');

    try {
      await ScanBatchController.instance.startBatchScan(_queuedImages);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _handleManualEntry() {
    AppLogger.info('UI', 'User tapped Manual entry on ScannerScreen');
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formattedDate =
        '${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
    final currency = CurrencyService.instance.currentCurrency;

    final manualReceipt = Receipt(
      id: 'res-manual-${DateTime.now().millisecondsSinceEpoch}',
      merchant: '',
      date: formattedDate,
      amount: 0.0,
      currency: currency,
      category: '',
      imagePath: null,
      items: const [],
      lineItems: const [],
    );

    context.push('/verification', extra: [manualReceipt]);
  }

  void _showToast(String message) {
    AppSnackBar.show(
      context,
      message: message,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _ScannerTopBar(
                        controller: controller,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accent: accent,
                        isFlashOn: _isFlashOn,
                        onToggleFlash: _toggleFlash,
                      ),
                      _ScanModeToggleBar(
                        isBulkMode: _isBulkMode,
                        accent: accent,
                        textSecondary: textSecondary,
                        onSingleSelect: () {
                          AppLogger.info(
                              'UI', 'User selected Single Scan mode');
                          setState(() {
                            _isBulkMode = false;
                            _queuedImages.clear();
                          });
                        },
                        onBulkSelect: () {
                          AppLogger.info('UI', 'User selected Bulk mode');
                          setState(() {
                            _isBulkMode = true;
                          });
                        },
                      ),
                      Expanded(
                        child: _ViewfinderArea(
                          controller: controller,
                          accent: accent,
                          textSecondary: textSecondary,
                          isCameraInitialized: _isCameraInitialized,
                          cameraController: _cameraController,
                          scanAnimationController: _scanAnimationController,
                          isBulkMode: _isBulkMode,
                          queuedCount: _queuedImages.length,
                        ),
                      ),
                      if (_isBulkMode && _queuedImages.isNotEmpty)
                        _QueueThumbnailCarousel(
                          queuedImages: _queuedImages,
                          accent: accent,
                          onRemoveItem: _removeQueuedImage,
                        ),
                      _ScannerBottomControls(
                        controller: controller,
                        accent: accent,
                        textSecondary: textSecondary,
                        isBulkMode: _isBulkMode,
                        isProcessing: _isSubmitting,
                        queuedCount: _queuedImages.length,
                        onPickGallery: _pickFromGallery,
                        onCapture: _capturePhoto,
                        onProcessQueue: _processQueueAndNavigate,
                        onManualEntry: _handleManualEntry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Extracted Top Bar Navigation & Flash Toggle
class _ScannerTopBar extends StatelessWidget {
  final AppThemeController controller;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final bool isFlashOn;
  final VoidCallback onToggleFlash;

  const _ScannerTopBar({
    required this.controller,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.isFlashOn,
    required this.onToggleFlash,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          NeumorphicButton(
            onPressed: () {
              AppLogger.info('UI', 'User tapped Back on ScannerScreen');
              context.pop();
            },
            style: NeumorphicStyle(
              depth: 4,
              intensity: 0.8,
              boxShape: const NeumorphicBoxShape.circle(),
              color: controller.currentBaseColor,
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: textPrimary,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                "Scan Receipt",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          NeumorphicButton(
            onPressed: onToggleFlash,
            style: NeumorphicStyle(
              depth: isFlashOn ? -4 : 4,
              intensity: 0.85,
              boxShape: const NeumorphicBoxShape.circle(),
              color: controller.currentBaseColor,
              border: isFlashOn
                  ? NeumorphicBorder(
                      color: accent.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : const NeumorphicBorder.none(),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(
              isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              size: 20,
              color: isFlashOn ? accent : textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extracted Scan Mode Segmented Toggle Selector Bar
class _ScanModeToggleBar extends StatelessWidget {
  final bool isBulkMode;
  final Color accent;
  final Color textSecondary;
  final VoidCallback onSingleSelect;
  final VoidCallback onBulkSelect;

  const _ScanModeToggleBar({
    required this.isBulkMode,
    required this.accent,
    required this.textSecondary,
    required this.onSingleSelect,
    required this.onBulkSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: NeumorphicCardWidget(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onSingleSelect,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !isBulkMode ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Single Scan",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: !isBulkMode ? Colors.white : textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onBulkSelect,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isBulkMode ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Bulk Mode (Max 10)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isBulkMode ? Colors.white : textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracted Camera Viewfinder & Scan Laser Frame
class _ViewfinderArea extends StatelessWidget {
  final AppThemeController controller;
  final Color accent;
  final Color textSecondary;
  final bool isCameraInitialized;
  final CameraController? cameraController;
  final AnimationController scanAnimationController;
  final bool isBulkMode;
  final int queuedCount;

  const _ViewfinderArea({
    required this.controller,
    required this.accent,
    required this.textSecondary,
    required this.isCameraInitialized,
    required this.cameraController,
    required this.scanAnimationController,
    required this.isBulkMode,
    required this.queuedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Neumorphic(
                  style: NeumorphicStyle(
                    depth: -6,
                    intensity: 0.9,
                    boxShape: NeumorphicBoxShape.roundRect(
                      BorderRadius.circular(24),
                    ),
                    color: controller.currentBaseColor,
                    border: NeumorphicBorder(
                      color: accent.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: isCameraInitialized && cameraController != null
                        ? CameraPreview(cameraController!)
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.camera_rounded,
                                size: 48,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CustomPaint(
                    painter: _ScannerBracketsPainter(
                      color: accent,
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: scanAnimationController,
                builder: (context, _) {
                  return Align(
                    alignment: Alignment(
                      0.0,
                      (scanAnimationController.value * 2) - 1,
                    ),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Neumorphic(
                    style: NeumorphicStyle(
                      depth: 4,
                      intensity: 0.7,
                      boxShape: NeumorphicBoxShape.roundRect(
                        BorderRadius.circular(20),
                      ),
                      color: controller.currentBaseColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        isBulkMode
                            ? "Queue: $queuedCount / 10 receipts"
                            : "Position receipt inside frame",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extracted Bulk Thumbnail Queue Carousel Bar
class _QueueThumbnailCarousel extends StatelessWidget {
  final List<XFile> queuedImages;
  final Color accent;
  final ValueChanged<int> onRemoveItem;

  const _QueueThumbnailCarousel({
    required this.queuedImages,
    required this.accent,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: queuedImages.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = queuedImages[index];
          return Stack(
            children: [
              NeumorphicCardWidget(
                padding: EdgeInsets.zero,
                borderRadius: 12,
                child: SizedBox(
                  width: 54,
                  height: 64,
                  child: item.path.isNotEmpty
                      ? Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: accent.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.receipt_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemoveItem(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Extracted Bottom Controls Bar
class _ScannerBottomControls extends StatelessWidget {
  final AppThemeController controller;
  final Color accent;
  final Color textSecondary;
  final bool isBulkMode;
  final bool isProcessing;
  final int queuedCount;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final VoidCallback onProcessQueue;
  final VoidCallback onManualEntry;

  const _ScannerBottomControls({
    required this.controller,
    required this.accent,
    required this.textSecondary,
    required this.isBulkMode,
    required this.isProcessing,
    required this.queuedCount,
    required this.onPickGallery,
    required this.onCapture,
    required this.onProcessQueue,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: 24,
        top: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSideButton(
            icon: Icons.photo_library_rounded,
            label: isBulkMode ? "Import" : "Gallery",
            onTap: isProcessing ? () {} : onPickGallery,
          ),
          GestureDetector(
            onTap: isProcessing ? null : onCapture,
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: 8,
                intensity: 0.9,
                boxShape: const NeumorphicBoxShape.circle(),
                color: controller.currentBaseColor,
                border: NeumorphicBorder(
                  color: accent.withValues(alpha: 0.4),
                  width: 2.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (queuedCount >= 10 || isProcessing)
                        ? Colors.grey
                        : accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          if (isBulkMode && queuedCount > 0)
            GestureDetector(
              onTap: isProcessing ? null : onProcessQueue,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Neumorphic(
                    style: NeumorphicStyle(
                      depth: isProcessing ? -2 : 6,
                      intensity: isProcessing ? 0.5 : 0.9,
                      boxShape: const NeumorphicBoxShape.circle(),
                      color:
                          isProcessing ? accent.withValues(alpha: 0.7) : accent,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isProcessing ? "Processing…" : "Process ($queuedCount)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildSideButton(
              icon: Icons.keyboard_rounded,
              label: "Manual",
              onTap: isProcessing ? () {} : onManualEntry,
            ),
        ],
      ),
    );
  }

  Widget _buildSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Neumorphic(
            style: NeumorphicStyle(
              depth: 4,
              intensity: 0.8,
              boxShape: const NeumorphicBoxShape.circle(),
              color: controller.currentBaseColor,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: textSecondary, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBracketsPainter extends CustomPainter {
  final Color color;

  _ScannerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 12.0;

    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..arcToPoint(
          Offset(size.width, r),
          radius: const Radius.circular(r),
        )
        ..lineTo(size.width, len),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..arcToPoint(
          Offset(r, size.height),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(len, size.height),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..arcToPoint(
          Offset(size.width, size.height - r),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerBracketsPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

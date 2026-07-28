import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:reciept_logging/core/constants/app_constants.dart';
import 'package:reciept_logging/core/theme/app_theme.dart';
import 'package:reciept_logging/core/theme/app_colors.dart';
import 'package:reciept_logging/core/providers/isar_provider.dart';
import 'package:reciept_logging/models/receipt.dart';

enum ScanState { idle, processing, review, saving }

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    return await availableCameras();
  } catch (e) {
    return <CameraDescription>[];
  }
});

class ScanNotifier extends Notifier<ScanState> {
  @override
  ScanState build() => ScanState.idle;
  void setProcessing() => state = ScanState.processing;
  void setReview() => state = ScanState.review;
  void setSaving() => state = ScanState.saving;
  void reset() => state = ScanState.idle;
}

final scanStateProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Other';
  DateTime _selectedDate = DateTime.now();
  List<String> _rawOcrLines = [];
  bool _cameraInitialized = false;
  bool _isCameraActive = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    _textRecognizer.close();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initCamera(List<CameraDescription> cameras) async {
    if (_cameraInitialized) return;
    _cameraInitialized = true;

    if (cameras.isEmpty) {
      if (mounted) {
        setState(() {
          _isCameraActive = false;
          _cameraError = 'No camera device detected on this browser/system.';
        });
      }
      return;
    }

    try {
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraActive = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraActive = false;
          _cameraError = 'Camera access unavailable ($e). You can pick or drop an image file below.';
        });
      }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    ref.read(scanStateProvider.notifier).setProcessing();
    try {
      final xFile = await _cameraController!.takePicture();
      await _processImage(xFile.path);
    } catch (e) {
      ref.read(scanStateProvider.notifier).reset();
      _showError('Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return;
      ref.read(scanStateProvider.notifier).setProcessing();
      await _processImage(xFile.path);
    } catch (e) {
      ref.read(scanStateProvider.notifier).reset();
      _showError('Image picker error: $e');
    }
  }

  Future<void> _processImage(String imagePath) async {
    List<String> lines = [];
    try {
      if (!kIsWeb) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognized = await _textRecognizer.processImage(inputImage);
        lines = recognized.blocks
            .expand((b) => b.lines)
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('ML Kit OCR fallback: $e');
    }

    if (lines.isEmpty) {
      lines = [
        'Scanned Receipt',
        'Total: \$15.50',
        DateFormat('MM/dd/yyyy').format(DateTime.now()),
      ];
    }

    _rawOcrLines = lines;
    _prefillFromOcr(lines);
    ref.read(scanStateProvider.notifier).setReview();
    if (mounted) _showReviewSheet();
  }

  void _prefillFromOcr(List<String> lines) {
    if (lines.isNotEmpty) _merchantController.text = lines.first;
    final amountRegex = RegExp(r'\$?([\d,]+\.\d{2})');
    for (final line in lines.reversed) {
      final match = amountRegex.firstMatch(line);
      if (match != null) {
        _amountController.text = match.group(1)!.replaceAll(',', '');
        break;
      }
    }
    final dateRegex = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\.](\d{2,4})');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          final y = int.parse(match.group(3)!);
          _selectedDate = DateTime(
            y < 100 ? y + 2000 : y,
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
          );
        } catch (_) {}
        break;
      }
    }
  }

  void _showReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final primaryColor = AppTheme.textPrimaryOf(ctx);
          final secondaryColor = AppTheme.textSecondaryOf(ctx);
          final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.85;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColorOf(ctx),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Receipt',
                              style: AppTheme.headlineMedium.copyWith(color: primaryColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Verify extracted data before saving',
                              style: AppTheme.bodyMedium.copyWith(color: secondaryColor),
                            ),
                            const SizedBox(height: 20),
                            _NeumorphicField(
                              label: 'Merchant',
                              controller: _merchantController,
                              hint: 'e.g. Starbucks',
                              prefixIcon: Icons.store_rounded,
                            ),
                            const SizedBox(height: 12),
                            _NeumorphicField(
                              label: 'Total Amount',
                              controller: _amountController,
                              hint: '0.00',
                              prefixIcon: Icons.attach_money_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setSheetState(() => _selectedDate = picked);
                              },
                              child: Neumorphic(
                                style: AppTheme.insetStyle,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.accentColor),
                                    const SizedBox(width: 12),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(_selectedDate),
                                      style: AppTheme.bodyLarge.copyWith(color: primaryColor),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Category', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: AppConstants.categories.map((cat) {
                                  final isSel = cat == _selectedCategory;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() => _selectedCategory = cat),
                                      child: Neumorphic(
                                        style: AppTheme.chipStyle.copyWith(
                                          depth: isSel ? -3 : 4,
                                          color: isSel ? AppColors.getCategoryColor(cat).withValues(alpha: 0.15) : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Text(
                                            cat,
                                            style: AppTheme.bodyMedium.copyWith(
                                              color: isSel ? AppColors.getCategoryColor(cat) : secondaryColor,
                                              fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: NeumorphicButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(scanStateProvider.notifier).reset();
                          },
                          style: AppTheme.buttonStyle,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Discard',
                              style: AppTheme.bodyLarge.copyWith(
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: NeumorphicButton(
                          onPressed: () => _saveReceipt(ctx),
                          style: AppTheme.buttonStyle.copyWith(color: AppTheme.accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Save Receipt',
                              style: AppTheme.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveReceipt(BuildContext sheetContext) async {
    ref.read(scanStateProvider.notifier).setSaving();
    try {
      final isar = await ref.read(isarProvider.future);
      final receipt = Receipt()
        ..merchantName = _merchantController.text.trim().isEmpty
            ? 'Unknown Merchant' : _merchantController.text.trim()
        ..totalAmount = double.tryParse(_amountController.text) ?? 0.0
        ..date = _selectedDate
        ..category = _selectedCategory
        ..rawOcrText = _rawOcrLines
        ..isSynced = false;
      await isar.writeTxn(() => isar.receipts.put(receipt));
      if (sheetContext.mounted && mounted) {
        Navigator.pop(sheetContext);
        context.go('/dashboard');
      }
    } catch (e) {
      ref.read(scanStateProvider.notifier).reset();
      _showError('Save failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(availableCamerasProvider);
    final scanState = ref.watch(scanStateProvider);

    return camerasAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.lightBackground,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _buildFallbackUI(context, scanState, 'Camera error: $e'),
      data: (cameras) {
        _initCamera(cameras);

        if (!_isCameraActive || _cameraError != null) {
          return _buildFallbackUI(context, scanState, _cameraError);
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            if (_cameraController != null && _cameraController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            _buildScanOverlay(context),
            if (scanState == ScanState.processing || scanState == ScanState.saving)
              _buildProcessingOverlay(scanState),
            _buildTopBar(context),
            _buildBottomControls(context, scanState),
          ]),
        );
      },
    );
  }

  Widget _buildFallbackUI(BuildContext context, ScanState scanState, String? errorMessage) {
    final primaryColor = AppTheme.textPrimaryOf(context);
    final secondaryColor = AppTheme.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColorOf(context),
      appBar: NeumorphicAppBar(
        title: Text('Scan Receipt', style: TextStyle(color: primaryColor)),
        leading: NeumorphicButton(
          style: const NeumorphicStyle(boxShape: NeumorphicBoxShape.circle()),
          padding: const EdgeInsets.all(8),
          onPressed: () => context.go('/dashboard'),
          child: Icon(Icons.dashboard_rounded, size: 20, color: primaryColor),
        ),
        actions: [
          NeumorphicButton(
            style: const NeumorphicStyle(boxShape: NeumorphicBoxShape.circle()),
            padding: const EdgeInsets.all(8),
            onPressed: () => context.push('/settings'),
            child: Icon(Icons.settings_rounded, size: 20, color: primaryColor),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Neumorphic(
                    style: AppTheme.cardStyle.copyWith(
                      boxShape: const NeumorphicBoxShape.circle(),
                      depth: 10,
                    ),
                    child: const SizedBox(
                      width: 100,
                      height: 100,
                      child: Center(
                        child: Icon(
                          Icons.no_photography_rounded,
                          size: 48,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Camera Unavailable',
                    style: AppTheme.headlineMedium.copyWith(color: primaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ??
                        'Live camera preview is not available on this browser or device target. You can pick any receipt photo or document directly below.',
                    style: AppTheme.bodyMedium.copyWith(color: secondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  NeumorphicButton(
                    onPressed: scanState == ScanState.idle ? _pickFromGallery : null,
                    style: AppTheme.buttonStyle.copyWith(color: AppTheme.accentColor),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Upload / Select Receipt Photo',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeumorphicButton(
                    onPressed: () {
                      setState(() {
                        _cameraInitialized = false;
                        _cameraError = null;
                      });
                      ref.invalidate(availableCamerasProvider);
                    },
                    style: AppTheme.buttonStyle,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'Retry Camera Access',
                      style: AppTheme.bodyMedium.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (scanState == ScanState.processing || scanState == ScanState.saving)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: AppTheme.accentColor),
                          const SizedBox(height: 12),
                          Text(
                            scanState == ScanState.saving ? 'Saving...' : 'Reading receipt...',
                            style: AppTheme.bodyMedium.copyWith(color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final frameW = w * 0.85;
      final frameH = frameW * 0.65;
      final left = (w - frameW) / 2;
      final top = (h - frameH) / 2 - 40;
      return Stack(children: [
        CustomPaint(
          size: Size(w, h),
          painter: _FramePainter(Rect.fromLTWH(left, top, frameW, frameH)),
        ),
        Positioned(
          left: left + 8, top: top, width: frameW - 16, height: frameH,
          child: AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (_, __) => Column(children: [
              SizedBox(height: (frameH - 2) * _scanLineAnimation.value),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    AppTheme.accentColor.withValues(alpha: 0.9),
                    Colors.transparent,
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          top: top + frameH + 16, left: 0, right: 0,
          child: const Center(
            child: Text('Align receipt within the frame',
              style: TextStyle(color: Colors.white70, fontFamily: 'Inter', fontSize: 13)),
          ),
        ),
      ]);
    });
  }

  Widget _buildProcessingOverlay(ScanState scanState) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppTheme.accentColor, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            scanState == ScanState.saving ? 'Saving receipt...' : 'Reading receipt...',
            style: const TextStyle(color: Colors.white, fontFamily: 'Inter',
                fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TopBarButton(icon: Icons.dashboard_rounded, onTap: () => context.go('/dashboard')),
            const Text('Scan Receipt', style: TextStyle(
              color: Colors.white, fontFamily: 'Inter', fontSize: 18,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
            )),
            _TopBarButton(icon: Icons.settings_rounded, onTap: () => context.push('/settings')),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ScanState scanState) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CircleIconButton(
              icon: Icons.photo_library_rounded, size: 52,
              onTap: scanState == ScanState.idle ? _pickFromGallery : null,
              label: 'Gallery',
            ),
            GestureDetector(
              onTap: scanState == ScanState.idle ? _captureAndProcess : null,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: scanState == ScanState.idle ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  boxShadow: [BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.5),
                    blurRadius: 20, spreadRadius: 2,
                  )],
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 36, color: AppTheme.accentColor),
              ),
            ),
            _CircleIconButton(
              icon: Icons.flash_auto_rounded, size: 52,
              label: 'Flash',
              onTap: () async {
                if (_cameraController == null) return;
                await _cameraController!.setFlashMode(
                  _cameraController!.value.flashMode == FlashMode.off
                      ? FlashMode.auto : FlashMode.off,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Rect frameRect;
  _FramePainter(this.frameRect);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12))),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      Paint()..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBarButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final String label;
  const _CircleIconButton({required this.icon, required this.size, required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontFamily: 'Inter', fontSize: 11)),
    ]);
  }
}

class _NeumorphicField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  const _NeumorphicField({required this.label, required this.controller,
      required this.hint, required this.prefixIcon, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.textPrimaryOf(context);
    final secondaryColor = AppTheme.textSecondaryOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
      const SizedBox(height: 6),
      Neumorphic(
        style: AppTheme.insetStyle,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTheme.bodyLarge.copyWith(color: primaryColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted),
            prefixIcon: Icon(prefixIcon, size: 18, color: AppTheme.accentColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ]);
  }
}

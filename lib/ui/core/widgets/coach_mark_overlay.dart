// File: lib/ui/core/widgets/coach_mark_overlay.dart

import 'package:flutter/rendering.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../theme/theme_controller.dart';

/// Interactive coach mark overlay with a semi-transparent dark backdrop
/// and a transparent cutout hole over [targetKey].
///
/// Taps within the cutout pass through to the real widget underneath.
/// Taps outside the cutout are absorbed to prevent accidental navigation.
class CoachMarkOverlay extends StatefulWidget {
  final GlobalKey targetKey;
  final bool isCircle;
  final double holePadding;
  final double cornerRadius;
  final String stepIndicator;
  final String title;
  final String subtitle;
  final String? errorMessage;
  final VoidCallback onSkip;
  final VoidCallback? onNext;
  final String nextLabel;
  final VoidCallback? onTargetTap;

  const CoachMarkOverlay({
    super.key,
    required this.targetKey,
    this.isCircle = true,
    this.holePadding = 10.0,
    this.cornerRadius = 16.0,
    required this.stepIndicator,
    required this.title,
    required this.subtitle,
    this.errorMessage,
    required this.onSkip,
    this.onNext,
    this.nextLabel = 'Next',
    this.onTargetTap,
  });

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseController.addListener(_measureTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _pulseController.removeListener(_measureTarget);
    _pulseController.dispose();
    super.dispose();
  }

  void _measureTarget() {
    if (!mounted) return;
    final context = widget.targetKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final measured = Rect.fromLTWH(
      offset.dx - widget.holePadding,
      offset.dy - widget.holePadding,
      size.width + widget.holePadding * 2,
      size.height + widget.holePadding * 2,
    );

    if (_targetRect != measured) {
      setState(() {
        _targetRect = measured;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final targetRect = _targetRect;

    // If target not yet measured, schedule measure on next frame
    if (targetRect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
      return const SizedBox.shrink();
    }

    final controller = AppThemeController.instance;
    final baseColor = controller.currentBaseColor;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final isDark = controller.isDarkMode;

    // Determine whether to place tooltip bubble above or below the cutout
    final targetCenterY = targetRect.center.dy;
    final isTargetInBottomHalf = targetCenterY > (screenSize.height / 2);

    return Material(
      type: MaterialType.transparency,
      child: HolePassThroughLayout(
        holeRect: targetRect,
        isCircle: widget.isCircle,
        child: Stack(
          children: [
            // Darkened scrim background with cutout hole
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: screenSize,
                  painter: _CoachMarkScrimPainter(
                    holeRect: targetRect,
                    isCircle: widget.isCircle,
                    cornerRadius: widget.cornerRadius,
                    accentColor: accent,
                    pulseValue: _pulseController.value,
                  ),
                );
              },
            ),

            // Top Header Bar: Unified Full-Width Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TutorialTopHeader(
                    stepIndicator: widget.stepIndicator,
                    onSkip: widget.onSkip,
                  ),
                ),
              ),
            ),

            // Active touch target directly over the cutout hole
            if (widget.onTargetTap != null)
              Positioned.fromRect(
                rect: targetRect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTargetTap,
                  child: const SizedBox.expand(),
                ),
              ),

            // Tooltip Bubble Card
            Positioned(
              left: 20,
              right: 20,
              top: isTargetInBottomHalf
                  ? (targetRect.top - 200).clamp(70.0, screenSize.height - 240)
                  : (targetRect.bottom + 16)
                      .clamp(70.0, screenSize.height - 240),
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.errorMessage != null
                        ? Colors.orange.withValues(alpha: 0.8)
                        : accent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Optional Error Banner (for scan failure fallback)
                    if (widget.errorMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.errorMessage!,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.errorMessage != null
                                ? Icons.refresh_rounded
                                : Icons.touch_app_rounded,
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (widget.onNext != null) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: NeumorphicButton(
                          onPressed: widget.onNext,
                          style: NeumorphicStyle(
                            depth: 3,
                            intensity: 0.85,
                            boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(12)),
                            color: accent,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.nextLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for semi-transparent backdrop with a punch-through cutout hole
/// and an animated pulsing glowing ring around the target.
class _CoachMarkScrimPainter extends CustomPainter {
  final Rect holeRect;
  final bool isCircle;
  final double cornerRadius;
  final Color accentColor;
  final double pulseValue;

  _CoachMarkScrimPainter({
    required this.holeRect,
    required this.isCircle,
    required this.cornerRadius,
    required this.accentColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;

    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    Path holePath;
    if (isCircle) {
      final center = holeRect.center;
      final radius = holeRect.width / 2;
      holePath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      holePath = Path()
        ..addRRect(
            RRect.fromRectAndRadius(holeRect, Radius.circular(cornerRadius)));
    }

    // Combine paths with even-odd rule to create punch-through hole
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      holePath,
    );

    canvas.drawPath(combinedPath, scrimPaint);

    // Pulsing outer ring (clean, no fuzzy glow)
    final ringAlpha = 0.6 + (pulseValue * 0.35);

    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: ringAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (isCircle) {
      final center = holeRect.center;
      final radius = (holeRect.width / 2) + (pulseValue * 2.0);
      canvas.drawCircle(center, radius, ringPaint);
    } else {
      final inflated = holeRect.inflate(pulseValue * 2.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            inflated, Radius.circular(cornerRadius + pulseValue * 2.0)),
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoachMarkScrimPainter oldDelegate) {
    return oldDelegate.holeRect != holeRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isCircle != isCircle;
  }
}

/// SingleChildRenderObjectWidget that lets pointer taps through inside [holeRect],
/// while absorbing all pointer taps outside of [holeRect].
class HolePassThroughLayout extends SingleChildRenderObjectWidget {
  final Rect holeRect;
  final bool isCircle;

  const HolePassThroughLayout({
    super.key,
    required this.holeRect,
    this.isCircle = true,
    required super.child,
  });

  @override
  RenderHolePassThrough createRenderObject(BuildContext context) {
    return RenderHolePassThrough(holeRect: holeRect, isCircle: isCircle);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderHolePassThrough renderObject) {
    renderObject
      ..holeRect = holeRect
      ..isCircle = isCircle;
  }
}

class RenderHolePassThrough extends RenderProxyBox {
  Rect holeRect;
  bool isCircle;

  RenderHolePassThrough({required this.holeRect, required this.isCircle});

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 1. If a child (like tooltip card buttons or Skip button) was tapped, handle it
    if (hitTestChildren(result, position: position)) {
      return true;
    }

    // 2. Check if the tap position is inside the punch-through cutout hole
    bool insideHole;
    if (isCircle) {
      final center = holeRect.center;
      final radius = holeRect.width / 2;
      insideHole = (position - center).distance <= radius;
    } else {
      insideHole = holeRect.contains(position);
    }

    if (insideHole) {
      // Allow the tap to pass through to the underlying widget (FAB / Save button)
      return false;
    }

    // 3. Tap was on the dimmed backdrop outside the hole — absorb it to prevent accidental taps
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

/// Unified full-width top header bar displaying the step indicator on the left
/// and the "Skip Guide" dismiss button on the right.
class TutorialTopHeader extends StatelessWidget {
  final String stepIndicator;
  final VoidCallback onSkip;

  const TutorialTopHeader({
    super.key,
    required this.stepIndicator,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final baseColor = controller.currentBaseColor;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stepIndicator,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSkip,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip Guide',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

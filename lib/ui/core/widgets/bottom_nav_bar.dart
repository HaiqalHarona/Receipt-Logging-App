import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/scan_batch_controller.dart';
import '../../../../cloud/services/quota_service.dart';
import '../theme/theme_controller.dart';
import 'scan_progress_snack_bar.dart';
import 'app_snack_bar.dart';

class AppBottomNavBar extends StatelessWidget {
  final String currentPath;

  const AppBottomNavBar({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        ScanBatchController.instance,
        QuotaService.instance,
      ]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final isDark = controller.isDarkMode;
        final accent = controller.accentColor;
        final inactiveColor = controller.secondaryTextColor;
        final navBg = controller.currentBaseColor;
        final isScanning = ScanBatchController.instance.isScanning;
        final hasReceiptsToReview =
            ScanBatchController.instance.hasReceiptsToReview;

        final screenWidth = MediaQuery.of(context).size.width;
        final margin5Percent = screenWidth * 0.05;

        return Padding(
          padding: EdgeInsets.only(
            left: margin5Percent,
            right: margin5Percent,
            bottom: margin5Percent,
            top: 18,
          ),
          child: SizedBox(
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Floating Rectangular Base Card (5% gap on sides and bottom)
                Neumorphic(
                  style: NeumorphicStyle(
                    depth: 6,
                    intensity: 0.85,
                    boxShape: NeumorphicBoxShape.roundRect(
                      BorderRadius.circular(16),
                    ),
                    color: navBg,
                  ),
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _NavItem(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          path: '/dashboard',
                          isActive: currentPath == '/dashboard',
                          accent: accent,
                          inactiveColor: inactiveColor,
                        ),
                        _NavItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'History',
                          path: '/history',
                          isActive: currentPath == '/history',
                          accent: accent,
                          inactiveColor: inactiveColor,
                        ),
                        // Middle space for floating camera FAB
                        const SizedBox(width: 58),
                        _NavItem(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI Chat',
                          path: '/ai-assistant',
                          isActive: currentPath == '/ai-assistant',
                          accent: accent,
                          inactiveColor: inactiveColor,
                        ),
                        _NavItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          path: '/settings',
                          isActive: currentPath == '/settings',
                          accent: accent,
                          inactiveColor: inactiveColor,
                        ),
                      ],
                    ),
                  ),
                ),

                // Camera / Pencil Action Button Layered Above App Bar
                Positioned(
                  top: -18,
                  child: _CenterScanFAB(
                    accent: accent,
                    navBg: navBg,
                    isDark: isDark,
                    isScanning: isScanning,
                    hasReceiptsToReview: hasReceiptsToReview,
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

class _CenterScanFAB extends StatelessWidget {
  final Color accent;
  final Color navBg;
  final bool isDark;
  final bool isScanning;
  final bool hasReceiptsToReview;

  const _CenterScanFAB({
    required this.accent,
    required this.navBg,
    required this.isDark,
    required this.isScanning,
    required this.hasReceiptsToReview,
  });

  @override
  Widget build(BuildContext context) {
    final disabledColor =
        isDark ? const Color(0xFF38383A) : Colors.grey.shade400;
    final isScanQuotaExhausted =
        QuotaService.instance.isScanQuotaExhausted && !hasReceiptsToReview;

    VoidCallback? onTapHandler;
    if (isScanning) {
      onTapHandler = null;
    } else if (hasReceiptsToReview) {
      onTapHandler = () {
        ScanProgressSnackBar.dismiss();
        context.push('/verification',
            extra: ScanBatchController.instance.completedReceipts);
      };
    } else if (isScanQuotaExhausted) {
      onTapHandler = () {
        AppSnackBar.show(
          context,
          message: QuotaService.instance.scanTooltip,
        );
      };
    } else {
      onTapHandler = () {
        context.push('/scanner');
      };
    }

    final IconData fabIcon = isScanning
        ? Icons.hourglass_top_rounded
        : (hasReceiptsToReview
            ? Icons.edit_rounded
            : (isScanQuotaExhausted
                ? Icons.lock_clock_rounded
                : Icons.camera_alt_rounded));

    final bool isDisabledState = isScanning || isScanQuotaExhausted;

    Widget fabWidget = GestureDetector(
      onTap: onTapHandler,
      behavior: HitTestBehavior.opaque,
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: isDisabledState ? -3 : 10,
          intensity: isDisabledState ? 0.4 : 0.95,
          boxShape: const NeumorphicBoxShape.circle(),
          color: isDisabledState ? disabledColor : accent,
          border: NeumorphicBorder(
            color: isDark
                ? (isDisabledState
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.5))
                : (isDisabledState
                    ? Colors.white24
                    : Colors.white.withValues(alpha: 0.9)),
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDisabledState ? disabledColor : null,
            gradient: isDisabledState
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      accent.withValues(alpha: 0.85),
                    ],
                  ),
            boxShadow: isDisabledState
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Icon(
            fabIcon,
            color: isDisabledState ? Colors.white70 : Colors.white,
            size: isScanning ? 25 : 28,
          ),
        ),
      ),
    );

    if (isScanQuotaExhausted) {
      return Tooltip(
        message: QuotaService.instance.scanTooltip,
        child: fabWidget,
      );
    }
    return fabWidget;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isActive;
  final Color accent;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isActive,
    required this.accent,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isActive) context.go(path);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  begin: inactiveColor,
                  end: isActive ? accent : inactiveColor,
                ),
                duration: const Duration(milliseconds: 200),
                builder: (context, color, _) {
                  return Icon(
                    icon,
                    color: color,
                    size: 22,
                  );
                },
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isActive ? accent : inactiveColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class NotchedPillClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;
  final double notchMargin;
  final double smoothRadius;

  const NotchedPillClipper({
    this.cornerRadius = 28.0,
    this.notchRadius = 34.0,
    this.notchMargin = 6.0,
    this.smoothRadius = 12.0,
  });

  static Path getNotchedPath(
    Size size, {
    required double cornerRadius,
    required double notchRadius,
    required double notchMargin,
    required double smoothRadius,
  }) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final centerX = w / 2;
    final effectiveRadius = notchRadius + notchMargin;
    final s = smoothRadius;

    final path = Path();
    path.moveTo(r, 0);

    // Top edge to start of left shoulder
    path.lineTo(centerX - effectiveRadius - s, 0);

    // Smooth rounded left shoulder into notch
    path.quadraticBezierTo(
      centerX - effectiveRadius,
      0,
      centerX - effectiveRadius,
      s,
    );

    // Rounded arc cutout
    path.arcToPoint(
      Offset(centerX + effectiveRadius, s),
      radius: Radius.circular(effectiveRadius),
      clockwise: false,
    );

    // Smooth rounded right shoulder back to top edge
    path.quadraticBezierTo(
      centerX + effectiveRadius,
      0,
      centerX + effectiveRadius + s,
      0,
    );

    // Top edge to top-right corner
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));

    // Right edge
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));

    // Bottom edge
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));

    // Left edge
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));

    path.close();
    return path;
  }

  @override
  Path getClip(Size size) {
    return getNotchedPath(
      size,
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
      notchMargin: notchMargin,
      smoothRadius: smoothRadius,
    );
  }

  @override
  bool shouldReclip(covariant NotchedPillClipper oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.notchMargin != notchMargin ||
        oldDelegate.smoothRadius != smoothRadius;
  }
}

class NotchedPillBorderPainter extends CustomPainter {
  final Color accentColor;
  final double cornerRadius;
  final double notchRadius;
  final double notchMargin;
  final double smoothRadius;

  NotchedPillBorderPainter({
    required this.accentColor,
    required this.cornerRadius,
    required this.notchRadius,
    required this.notchMargin,
    required this.smoothRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPillClipper.getNotchedPath(
      size,
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
      notchMargin: notchMargin,
      smoothRadius: smoothRadius,
    );

    // Glowing outer neon blur stroke
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Sharp main neon outline stroke
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant NotchedPillBorderPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.notchMargin != notchMargin ||
        oldDelegate.smoothRadius != smoothRadius;
  }
}

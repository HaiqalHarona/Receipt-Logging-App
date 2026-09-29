import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/theme_controller.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = "Continue with Google",
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final baseColor = controller.currentBaseColor;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 4,
            intensity: 0.85,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
            color: baseColor,
            border: NeumorphicBorder(
              color: textPrimary.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: controller.accentColor,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleLogoWidget(size: 20),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Precise vector render of the multi-colored Google "G" brand icon.
class _GoogleLogoWidget extends StatelessWidget {
  final double size;

  const _GoogleLogoWidget({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));

    // Red arc (top)
    canvas.drawArc(rect, -2.4, 1.4, false, redPaint);

    // Yellow arc (left)
    canvas.drawArc(rect, 2.3, 1.6, false, yellowPaint);

    // Green arc (bottom)
    canvas.drawArc(rect, 0.7, 1.6, false, greenPaint);

    // Blue arc (right-bottom)
    canvas.drawArc(rect, -0.4, 1.1, false, bluePaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      center.dx - (strokeWidth * 0.2),
      center.dy - (strokeWidth / 2),
      radius + (strokeWidth * 0.2),
      strokeWidth,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

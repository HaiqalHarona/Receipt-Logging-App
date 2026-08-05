// File: lib/ui/features/dashboard/views/widgets/monthly_spending_graph_card.dart

import 'dart:math' as math;
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../view_models/dashboard_view_model.dart';

/// Protruded Neumorphic card displaying an interactive monthly spending line graph.
///
/// Houses the section title, dynamic description, and a [CustomPaint] line
/// graph plotting the last [DashboardViewModel.graphMonthCount] months of spending.
///
/// Clicking a data point displays a floating tooltip with amount and date
/// (e.g. `110.02 - 03/26`).
class MonthlySpendingGraphCard extends StatefulWidget {
  final DashboardViewModel viewModel;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const MonthlySpendingGraphCard({
    super.key,
    required this.viewModel,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  State<MonthlySpendingGraphCard> createState() => _MonthlySpendingGraphCardState();
}

class _MonthlySpendingGraphCardState extends State<MonthlySpendingGraphCard> {
  int? _selectedIndex;

  static const double _paddingLeft = 28.0;
  static const double _paddingRight = 10.0;
  static const double _paddingTop = 10.0;
  static const double _paddingBottom = 22.0;

  void _handleTapUp(TapUpDetails details, Size size, List<MonthlySpendingPoint> points) {
    if (points.isEmpty) return;

    final plotLeft = _paddingLeft;
    final plotRight = size.width - _paddingRight;
    final plotTop = _paddingTop;
    final plotBottom = size.height - _paddingBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final maxAmount = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final yRange = maxAmount > 0 ? maxAmount : 1.0;
    final n = points.length;

    final touchPos = details.localPosition;

    int? closestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < n; i++) {
      final x = plotLeft + (i / (n - 1)) * plotWidth;
      final y = plotBottom - (points[i].amount / yRange) * plotHeight;
      final dx = touchPos.dx - x;
      final dy = touchPos.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Touch threshold: 28.0 logical pixels
    if (minDistance <= 28.0 && closestIndex != null) {
      setState(() {
        if (_selectedIndex == closestIndex) {
          _selectedIndex = null; // Toggle off if tapping already selected point
        } else {
          _selectedIndex = closestIndex;
        }
      });
    } else {
      setState(() {
        _selectedIndex = null; // Dismiss if tapping far away
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.viewModel.monthlySpendingHistory;
    final symbol = widget.viewModel.currentSymbol;
    final n = DashboardViewModel.graphMonthCount;

    return Neumorphic(
      style: NeumorphicStyle(
        depth: 4,
        intensity: 0.75,
        boxShape: NeumorphicBoxShape.roundRect(const BorderRadius.all(Radius.circular(18))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Trend',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.textPrimary,
                  ),
                ),
                Text(
                  '$symbol spent the last $n months',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Line Graph with Touch Detection ──────────────────────────────
            SizedBox(
              height: 120,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(constraints.maxWidth, 120);
                  return GestureDetector(
                    onTapUp: (details) => _handleTapUp(details, canvasSize, points),
                    behavior: HitTestBehavior.opaque,
                    child: CustomPaint(
                      size: canvasSize,
                      painter: _LineGraphPainter(
                        points: points,
                        accentColor: widget.accent,
                        axisLabelColor: widget.textSecondary,
                        textPrimary: widget.textPrimary,
                        currencySymbol: symbol,
                        selectedIndex: _selectedIndex,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painter ──────────────────────────────────────────────────────────

class _LineGraphPainter extends CustomPainter {
  final List<MonthlySpendingPoint> points;
  final Color accentColor;
  final Color axisLabelColor;
  final Color textPrimary;
  final String currencySymbol;
  final int? selectedIndex;

  static const double _paddingLeft = 28.0;
  static const double _paddingRight = 10.0;
  static const double _paddingTop = 10.0;
  static const double _paddingBottom = 22.0;

  _LineGraphPainter({
    required this.points,
    required this.accentColor,
    required this.axisLabelColor,
    required this.textPrimary,
    required this.currencySymbol,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plotLeft = _paddingLeft;
    final plotRight = size.width - _paddingRight;
    final plotTop = _paddingTop;
    final plotBottom = size.height - _paddingBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    // ── Axis label style ──────────────────────────────────────────────────
    final labelStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Y-axis label (currency symbol)
    _drawText(
      canvas,
      currencySymbol,
      Offset(0, plotTop - 2),
      labelStyle,
    );

    // X-axis label ('date')
    _drawText(
      canvas,
      'date',
      Offset(plotRight - 20, size.height - 14),
      labelStyle,
    );

    // ── Compute Y range ───────────────────────────────────────────────────
    final maxAmount = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final yRange = maxAmount > 0 ? maxAmount : 1.0;

    // ── Map each data point to canvas coordinates ─────────────────────────
    final n = points.length;
    List<Offset> offsets = [];
    for (int i = 0; i < n; i++) {
      final x = plotLeft + (i / (n - 1)) * plotWidth;
      final y = plotBottom - (points[i].amount / yRange) * plotHeight;
      offsets.add(Offset(x, y));
    }

    // ── Axis lines ────────────────────────────────────────────────────────
    final axisPaint = Paint()
      ..color = axisLabelColor.withAlpha(60)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom), axisPaint);
    canvas.drawLine(Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom), axisPaint);

    // ── Line path ─────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // ── Fill area beneath the line ────────────────────────────────────────
    final fillPath = Path()
      ..moveTo(offsets.first.dx, plotBottom)
      ..lineTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      fillPath.lineTo(offsets[i].dx, offsets[i].dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, plotBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentColor.withAlpha(60), accentColor.withAlpha(6)],
      ).createShader(Rect.fromLTWH(plotLeft, plotTop, plotWidth, plotHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // ── Data point markers ────────────────────────────────────────────────
    final dotFill = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final dotBorder = Paint()
      ..color = accentColor.withAlpha(180)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      if (selectedIndex == i) {
        // Draw glow highlight ring for selected node
        final glowPaint = Paint()
          ..color = accentColor.withAlpha(80)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(o, 8.0, glowPaint);

        final selectedBorder = Paint()
          ..color = accentColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(o, 4.0, dotFill);
        canvas.drawCircle(o, 6.5, selectedBorder);
      } else {
        canvas.drawCircle(o, 3.5, dotFill);
        canvas.drawCircle(o, 5.0, dotBorder);
      }
    }

    // ── Selected Guideline & Tooltip Bubble ───────────────────────────────
    if (selectedIndex != null && selectedIndex! < offsets.length) {
      final idx = selectedIndex!;
      final point = points[idx];
      final targetOffset = offsets[idx];

      // Vertical guide line down to X-axis
      final guidePaint = Paint()
        ..color = accentColor.withAlpha(120)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        targetOffset,
        Offset(targetOffset.dx, plotBottom),
        guidePaint,
      );

      // Tooltip content: e.g. "110.02 - 03/26"
      final amountStr = point.amount.toStringAsFixed(2);
      final tooltipText = '$amountStr - ${point.label}';

      final tooltipStyle = const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      );

      final tp = TextPainter(
        text: TextSpan(text: tooltipText, style: tooltipStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      const paddingH = 8.0;
      const paddingV = 4.0;
      final bubbleWidth = tp.width + (paddingH * 2);
      final bubbleHeight = tp.height + (paddingV * 2);

      // Position bubble above the point, clamped to plot edges
      double bubbleDx = targetOffset.dx - (bubbleWidth / 2);
      bubbleDx = bubbleDx.clamp(0.0, size.width - bubbleWidth);

      double bubbleDy = targetOffset.dy - bubbleHeight - 8.0;
      if (bubbleDy < 0) {
        bubbleDy = targetOffset.dy + 8.0; // Show below point if near top
      }

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleDx, bubbleDy, bubbleWidth, bubbleHeight),
        const Radius.circular(6),
      );

      // Background bubble fill
      final bubbleBgPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill;

      // Border outline
      final bubbleBorderPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(bubbleRect, bubbleBgPaint);
      canvas.drawRRect(bubbleRect, bubbleBorderPaint);

      // Render tooltip text centered inside bubble
      tp.paint(
        canvas,
        Offset(bubbleDx + paddingH, bubbleDy + paddingV),
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_LineGraphPainter old) =>
      old.points != points ||
      old.accentColor != accentColor ||
      old.currencySymbol != currencySymbol ||
      old.axisLabelColor != axisLabelColor ||
      old.textPrimary != textPrimary ||
      old.selectedIndex != selectedIndex;
}

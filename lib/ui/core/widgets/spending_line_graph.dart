// File: lib/ui/core/widgets/spending_line_graph.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../features/dashboard/view_models/dashboard_view_model.dart';

/// Reusable interactive Neumorphic spending line graph with touch detection,
/// data points, smooth cubic curve, gradient fill, and floating tooltips.
class SpendingLineGraph extends StatefulWidget {
  final List<MonthlySpendingPoint> points;
  final Color accentColor;
  final Color textPrimary;
  final Color textSecondary;
  final String currencySymbol;
  final double height;
  final int? initialSelectedIndex;
  final ValueChanged<int?>? onPointSelected;

  const SpendingLineGraph({
    super.key,
    required this.points,
    required this.accentColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.currencySymbol,
    this.height = 120.0,
    this.initialSelectedIndex,
    this.onPointSelected,
  });

  @override
  State<SpendingLineGraph> createState() => _SpendingLineGraphState();
}

class _SpendingLineGraphState extends State<SpendingLineGraph> {
  int? _selectedIndex;

  static const double _paddingLeft = 28.0;
  static const double _paddingRight = 10.0;
  static const double _paddingTop = 10.0;
  static const double _paddingBottom = 22.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  void didUpdateWidget(covariant SpendingLineGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.points, widget.points)) {
      _selectedIndex = null;
    }
  }

  void _handleTapUp(
      TapUpDetails details, Size size, List<MonthlySpendingPoint> points) {
    if (points.isEmpty) return;

    final plotLeft = _paddingLeft;
    final plotRight = size.width - _paddingRight;
    final plotTop = _paddingTop;
    final plotBottom = size.height - _paddingBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final maxAmount =
        points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final yRange = maxAmount > 0 ? maxAmount : 1.0;
    final n = points.length;

    final touchPos = details.localPosition;

    int? closestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < n; i++) {
      final x = n > 1
          ? plotLeft + (i / (n - 1)) * plotWidth
          : plotLeft + plotWidth / 2;
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
          _selectedIndex = null;
        } else {
          _selectedIndex = closestIndex;
        }
      });
    } else {
      setState(() {
        _selectedIndex = null;
      });
    }

    widget.onPointSelected?.call(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, widget.height);
          return GestureDetector(
            onTapUp: (details) =>
                _handleTapUp(details, canvasSize, widget.points),
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              size: canvasSize,
              painter: SpendingLineGraphPainter(
                points: widget.points,
                accentColor: widget.accentColor,
                axisLabelColor: widget.textSecondary,
                textPrimary: widget.textPrimary,
                currencySymbol: widget.currencySymbol,
                selectedIndex: _selectedIndex,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// CustomPainter rendering grid lines, cubic Bézier spending curves,
/// data point markers, and interactive selected tooltip bubbles.
class SpendingLineGraphPainter extends CustomPainter {
  final List<MonthlySpendingPoint> points;
  final Color accentColor;
  final Color axisLabelColor;
  final Color textPrimary;
  final String currencySymbol;
  final int? selectedIndex;

  SpendingLineGraphPainter({
    required this.points,
    required this.accentColor,
    required this.axisLabelColor,
    required this.textPrimary,
    required this.currencySymbol,
    this.selectedIndex,
  });

  static const double _paddingLeft = 28.0;
  static const double _paddingRight = 10.0;
  static const double _paddingTop = 10.0;
  static const double _paddingBottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plotLeft = _paddingLeft;
    final plotRight = size.width - _paddingRight;
    final plotTop = _paddingTop;
    final plotBottom = size.height - _paddingBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final maxAmount =
        points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    final yRange = maxAmount > 0 ? maxAmount : 1.0;

    // ── Horizontal guide lines (0%, 50%, 100%) ────────────────────────────
    final gridPaint = Paint()
      ..color = axisLabelColor.withAlpha(25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = plotBottom - (fraction * plotHeight);
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotRight, y),
        gridPaint,
      );

      final val = fraction * maxAmount;
      final valStr = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toStringAsFixed(0);
      final labelStyle = TextStyle(
        color: axisLabelColor.withAlpha(160),
        fontSize: 8.5,
        fontWeight: FontWeight.w500,
      );
      _drawText(
        canvas,
        valStr,
        Offset(0, y - 5),
        labelStyle,
      );
    }

    // ── Calculate point pixel coordinates ─────────────────────────────────
    final n = points.length;
    final offsets = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = n > 1
          ? plotLeft + (i / (n - 1)) * plotWidth
          : plotLeft + plotWidth / 2;
      final y = plotBottom - (points[i].amount / yRange) * plotHeight;
      offsets.add(Offset(x, y));
    }

    // ── X-axis date / month labels ────────────────────────────────────────
    if (n <= 8) {
      final labelStyle = TextStyle(
        color: axisLabelColor.withAlpha(190),
        fontSize: 8.5,
        fontWeight: FontWeight.w500,
      );

      for (int i = 0; i < n; i++) {
        final o = offsets[i];
        final label = points[i].label;
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(o.dx - (tp.width / 2), plotBottom + 5));
      }
    } else {
      final omittedStyle = TextStyle(
        color: axisLabelColor.withAlpha(190),
        fontSize: 8.5,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'Dates Omitted - Click On Points For Details',
          style: omittedStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centerX = plotLeft + (plotWidth / 2);
      final maxAvailableX = size.width - tp.width;
      final x = maxAvailableX > 0
          ? (centerX - (tp.width / 2)).clamp(0.0, maxAvailableX)
          : centerX - (tp.width / 2);
      tp.paint(canvas, Offset(x, plotBottom + 5));
    }

    if (offsets.length < 2) {
      if (offsets.length == 1) {
        final dotFill = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offsets.first, 4.0, dotFill);
      }
      return;
    }

    // ── Straight spending line path ───────────────────────────────────────
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }

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

    // Draw the straight spending line
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

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

      // Tooltip content: e.g. "$110.02 - 03/26"
      final amountStr = '$currencySymbol${point.amount.toStringAsFixed(2)}';
      final tooltipText = '$amountStr • ${point.label}';

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

      double bubbleDx = targetOffset.dx - (bubbleWidth / 2);
      bubbleDx = bubbleDx.clamp(0.0, size.width - bubbleWidth);

      double bubbleDy = targetOffset.dy - bubbleHeight - 8.0;
      if (bubbleDy < 0) {
        bubbleDy = targetOffset.dy + 8.0;
      }

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleDx, bubbleDy, bubbleWidth, bubbleHeight),
        const Radius.circular(6),
      );

      final bubbleBgPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill;

      final bubbleBorderPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(bubbleRect, bubbleBgPaint);
      canvas.drawRRect(bubbleRect, bubbleBorderPaint);

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
  bool shouldRepaint(SpendingLineGraphPainter old) => true;
}

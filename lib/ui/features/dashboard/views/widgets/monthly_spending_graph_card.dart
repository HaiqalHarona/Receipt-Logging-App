// File: lib/ui/features/dashboard/views/widgets/monthly_spending_graph_card.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../view_models/dashboard_view_model.dart';

/// Protruded Neumorphic card displaying a monthly spending line graph.
///
/// Houses the section title, dynamic description, and a [CustomPaint] line
/// graph that plots the last [DashboardViewModel.graphMonthCount] months
/// of spending in the active currency.
///
/// Axis labels are intentionally minimal:
///   - Y-axis labelled with the active currency symbol (e.g. `$`).
///   - X-axis labelled with the static string `date`.
///   - No numeric tick labels are rendered on either axis.
class MonthlySpendingGraphCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final points = viewModel.monthlySpendingHistory;
    final symbol = viewModel.currentSymbol;
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
                    color: textPrimary,
                  ),
                ),
                Text(
                  '$symbol spent the last $n months',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Line Graph ────────────────────────────────────────────────────
            SizedBox(
              height: 120,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, 120),
                    painter: _LineGraphPainter(
                      points: points,
                      accentColor: accent,
                      axisLabelColor: textSecondary,
                      currencySymbol: symbol,
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
  final String currencySymbol;

  /// Fractional padding from each edge before drawing the plot area.
  static const double _paddingLeft = 28.0;
  static const double _paddingRight = 10.0;
  static const double _paddingTop = 10.0;
  static const double _paddingBottom = 22.0;

  _LineGraphPainter({
    required this.points,
    required this.accentColor,
    required this.axisLabelColor,
    required this.currencySymbol,
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

    // Y-axis label (currency symbol) — top-left of the plot area.
    _drawText(
      canvas,
      currencySymbol,
      Offset(0, plotTop - 2),
      labelStyle,
    );

    // X-axis label — bottom-right of the plot area.
    _drawText(
      canvas,
      'date',
      Offset(plotRight - 20, size.height - 14),
      labelStyle,
    );

    // ── Compute Y range ───────────────────────────────────────────────────
    final maxAmount = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);
    // Guard against all-zero data so we don't divide by zero.
    final yRange = maxAmount > 0 ? maxAmount : 1.0;

    // ── Map each data point to canvas coordinates ─────────────────────────
    final n = points.length;
    List<Offset> offsets = [];
    for (int i = 0; i < n; i++) {
      final x = plotLeft + (i / (n - 1)) * plotWidth;
      final y = plotBottom - (points[i].amount / yRange) * plotHeight;
      offsets.add(Offset(x, y));
    }

    // ── Axis lines (subtle, semi-transparent) ─────────────────────────────
    final axisPaint = Paint()
      ..color = axisLabelColor.withAlpha(60)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    // Horizontal base line.
    canvas.drawLine(Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom), axisPaint);
    // Vertical left line.
    canvas.drawLine(Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom), axisPaint);

    // ── Line path (linear segments for now; smooth bezier ready to add) ───
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

    // ── Fill area beneath the line (translucent accent gradient) ─────────
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

    for (final o in offsets) {
      canvas.drawCircle(o, 3.5, dotFill);
      canvas.drawCircle(o, 5.0, dotBorder);
    }
  }

  /// Helper to draw a [TextSpan] at a given [Offset].
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
      old.axisLabelColor != axisLabelColor;
}

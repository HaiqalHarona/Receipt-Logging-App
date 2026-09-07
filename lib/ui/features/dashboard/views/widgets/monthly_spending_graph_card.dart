// File: lib/ui/features/dashboard/views/widgets/monthly_spending_graph_card.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/spending_line_graph.dart';
import '../../view_models/dashboard_view_model.dart';
import 'spending_summary_card.dart';

/// Protruded Neumorphic card displaying an interactive spending line graph.
///
/// Features:
/// - Header with dynamic description and direct navigation to detailed /analytics screen
/// - Segmented selector for (1W, 4W, 3M)
/// - Reusable interactive [SpendingLineGraph] with touch tooltips
/// - Encompassed indented [SpendingSummaryCard] carousel
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
  State<MonthlySpendingGraphCard> createState() =>
      _MonthlySpendingGraphCardState();
}

class _MonthlySpendingGraphCardState extends State<MonthlySpendingGraphCard> {
  String _getSubtitleText(TimelineFilter filter, String symbol) {
    switch (filter) {
      case TimelineFilter.oneWeek:
        return '$symbol spent (Past 7 Days)';
      case TimelineFilter.fourWeeks:
        return '$symbol spent (Past 4 Weeks)';
      case TimelineFilter.thisMonth:
        return '$symbol spent (This Month)';
      case TimelineFilter.threeMonths:
        return '$symbol spent (Last 3 Months)';
      case TimelineFilter.sixMonths:
        return '$symbol spent (Last 6 Months)';
      case TimelineFilter.twelveMonths:
        return '$symbol spent (Last 12 Months)';
      case TimelineFilter.ytd:
        return '$symbol spent (Year to Date)';
      case TimelineFilter.allTime:
        return '$symbol spent (All-Time)';
    }
  }

  Widget _buildSegmentItem({
    required String label,
    required TimelineFilter filter,
    required TimelineFilter activeFilter,
  }) {
    final isSelected = filter == activeFilter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            widget.viewModel.setTimeline(filter);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: isSelected
            ? Neumorphic(
                style: NeumorphicStyle(
                  depth: 2.5,
                  intensity: 0.9,
                  color: NeumorphicTheme.baseColor(context),
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(8)),
                  border: NeumorphicBorder(
                    color: widget.accent.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.accent,
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTimeline = widget.viewModel.selectedTimeline;
    final points = widget.viewModel.monthlySpendingHistory;
    final symbol = widget.viewModel.currentSymbol;
    final subtitleText = _getSubtitleText(activeTimeline, symbol);

    return Neumorphic(
      style: NeumorphicStyle(
        depth: 4,
        intensity: 0.75,
        boxShape: NeumorphicBoxShape.roundRect(
            const BorderRadius.all(Radius.circular(18))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header (Title, Subtitle & Analytics Navigation) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: widget.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/analytics'),
                  child: Neumorphic(
                    style: NeumorphicStyle(
                      depth: 2.5,
                      intensity: 0.85,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(10)),
                      color: NeumorphicTheme.baseColor(context),
                      border: NeumorphicBorder(
                        color: widget.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_graph_rounded,
                            size: 13, color: widget.accent),
                        const SizedBox(width: 5),
                        Text(
                          'Analytics',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.accent,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded,
                            size: 13, color: widget.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Grouped Segmented Timeline Selector (1W · 4W · 3M) ──
            Neumorphic(
              style: NeumorphicStyle(
                depth: -2.5,
                intensity: 0.85,
                boxShape:
                    NeumorphicBoxShape.roundRect(BorderRadius.circular(11)),
                color: NeumorphicTheme.baseColor(context),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildSegmentItem(
                    label: '1W',
                    filter: TimelineFilter.oneWeek,
                    activeFilter: activeTimeline,
                  ),
                  _buildSegmentItem(
                    label: '4W',
                    filter: TimelineFilter.fourWeeks,
                    activeFilter: activeTimeline,
                  ),
                  _buildSegmentItem(
                    label: '3M',
                    filter: TimelineFilter.threeMonths,
                    activeFilter: activeTimeline,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Line Graph with Touch Tooltip Support ────────────────────────
            SpendingLineGraph(
              points: points,
              accentColor: widget.accent,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              currencySymbol: symbol,
              height: 120,
            ),
            const SizedBox(height: 16),

            // ── Encompassed Indented Spending Summary Carousel ───────────────
            SpendingSummaryCard(
              viewModel: widget.viewModel,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              accent: widget.accent,
            ),
          ],
        ),
      ),
    );
  }
}

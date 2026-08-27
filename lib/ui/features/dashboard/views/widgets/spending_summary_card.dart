// File: lib/ui/features/dashboard/views/widgets/spending_summary_card.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../view_models/dashboard_view_model.dart';

/// Neumorphic spending summary card bound to active graph timeline option.
///
/// Features fixed uniform dimensions, calculation caching, read-only dot indicators,
/// and programmatically slides to match the selected graph timeline option.
/// Manual swiping is disabled.
class SpendingSummaryCard extends StatefulWidget {
  final DashboardViewModel viewModel;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const SpendingSummaryCard({
    super.key,
    required this.viewModel,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  State<SpendingSummaryCard> createState() => _SpendingSummaryCardState();
}

class _SpendingSummaryCardState extends State<SpendingSummaryCard> {
  static const int _periodCount = 6;
  static const List<SpendingSummaryPeriod> _periods = [
    SpendingSummaryPeriod.oneMonth, // 0: 1m
    SpendingSummaryPeriod.threeMonths, // 1: 3m
    SpendingSummaryPeriod.sixMonths, // 2: 6m
    SpendingSummaryPeriod.twelveMonths, // 3: 12m
    SpendingSummaryPeriod.ytd, // 4: YTD
    SpendingSummaryPeriod.allTime, // 5: All
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  int _targetIndexForTimeline(TimelineFilter filter) {
    switch (filter) {
      case TimelineFilter.thisMonth:
        return 0;
      case TimelineFilter.threeMonths:
        return 1;
      case TimelineFilter.sixMonths:
        return 2;
      case TimelineFilter.twelveMonths:
        return 3;
      case TimelineFilter.ytd:
        return 4;
      case TimelineFilter.allTime:
        return 5;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPage = _targetIndexForTimeline(widget.viewModel.selectedTimeline);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex =
        _targetIndexForTimeline(widget.viewModel.selectedTimeline);

    if (_currentPage != activeIndex) {
      _currentPage = activeIndex;
      if (_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.animateToPage(
              activeIndex,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }

    return Neumorphic(
      style: NeumorphicStyle(
        depth: -3, // Indented recessed container
        intensity: 0.8,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
        color: NeumorphicTheme.baseColor(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(98).clamp(98.0, 135.0),
        width: double.infinity,
        child: PageView.builder(
          controller: _pageController,
          physics:
              const NeverScrollableScrollPhysics(), // Disabled manual swiping
          itemCount: _periodCount,
          itemBuilder: (context, realIndex) {
            final period = _periods[realIndex];
            final summary = widget.viewModel.getSpendingSummary(period);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Row 1: Title (top-left) & Currency Badge (top-right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      summary.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: widget.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.viewModel.currentCurrencyCode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Row 2: Total Spending Amount
                Text(
                  summary.formattedTotal,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: widget.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),

                // Row 3: Comparison Badge (Red if +%, Green if -%, Gray if 0%, Omitted for All-Time)
                if (summary.percentageChange != null &&
                    summary.comparisonLabel != null) ...[
                  _buildComparisonBadge(summary),
                  const SizedBox(height: 2),
                ],

                // Row 4: Record Count
                Text(
                  "${summary.transactionCount} record${summary.transactionCount == 1 ? '' : 's'}",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: widget.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the spending comparison badge with a tap-triggered Tooltip for Row 3.
  Widget _buildComparisonBadge(SpendingSummaryData summary) {
    if (summary.percentageChange == null || summary.comparisonLabel == null) {
      return const SizedBox.shrink();
    }

    final change = summary.percentageChange!;
    final isIncrease = change > 0.0;
    final isDecrease = change < 0.0;

    final Color badgeColor = isIncrease
        ? Colors.red.shade400
        : (isDecrease ? Colors.green.shade400 : widget.textSecondary);

    final IconData badgeIcon = isIncrease
        ? Icons.trending_up_rounded
        : (isDecrease
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded);

    final String prefix = isIncrease ? '+' : '';
    final String badgeText = '$prefix${change.toStringAsFixed(1)}%';

    return Tooltip(
      message: summary.comparisonLabel!,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 12, color: badgeColor),
            const SizedBox(width: 3),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

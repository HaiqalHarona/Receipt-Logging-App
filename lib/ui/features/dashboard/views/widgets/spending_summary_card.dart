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
    SpendingSummaryPeriod.oneMonth,     // 0: 1m
    SpendingSummaryPeriod.threeMonths,  // 1: 3m
    SpendingSummaryPeriod.sixMonths,    // 2: 6m
    SpendingSummaryPeriod.twelveMonths, // 3: 12m
    SpendingSummaryPeriod.ytd,          // 4: YTD
    SpendingSummaryPeriod.allTime,      // 5: All
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
    final activeIndex = _targetIndexForTimeline(widget.viewModel.selectedTimeline);

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Column(
          children: [
            // Carousel Viewport (Manual scrolling disabled)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disabled manual swiping
                itemCount: _periodCount,
                itemBuilder: (context, realIndex) {
                  final period = _periods[realIndex];
                  final summary = widget.viewModel.getSpendingSummary(period);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      const SizedBox(height: 6),
                      Text(
                        summary.formattedTotal,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: widget.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Read-only Carousel Dot Indicators (6 elements)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_periodCount, (index) {
                final isSelected = index == activeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.accent
                        : widget.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

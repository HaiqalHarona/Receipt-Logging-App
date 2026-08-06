// File: lib/ui/features/dashboard/views/widgets/spending_summary_card.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../view_models/dashboard_view_model.dart';

/// Neumorphic 6-element looping manual carousel displaying aggregated spending
/// totals across 6 periods (1m, 3m, 6m, 12m, YTD, All).
///
/// Features fixed uniform dimensions, calculation caching, infinite manual sliding,
/// and 6 embedded dot indicators at the bottom.
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
  int _currentPage = 1000 * _periodCount; // Start at 0 mod 6 (1m)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDotTapped(int index) {
    final currentReal = _currentPage % _periodCount;
    final targetPage = _currentPage + (index - currentReal);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _currentPage % _periodCount;

    return NeumorphicCardWidget(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        height: 128,
        width: double.infinity,
        child: Column(
          children: [
            // Carousel Viewport
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, virtualIndex) {
                  final realIndex = virtualIndex % _periodCount;
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: widget.accent,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // 6 Dot Indicators embedded inside bottom of Neumorphic card
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_periodCount, (i) {
                final isActive = i == activeIndex;
                return GestureDetector(
                  onTap: () => _onDotTapped(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16.0 : 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: isActive ? widget.accent : widget.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
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

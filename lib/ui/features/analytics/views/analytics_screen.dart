// File: lib/ui/features/analytics/views/analytics_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../services/currency_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/widgets/spending_line_graph.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../history/views/widgets/receipt_list_item_widget.dart';

/// Comprehensive Spending Analytics Screen ("The New Page").
///
/// Features:
/// 1. Displays ALL timeline options (1W, 4W, 1M, 3M, 6M, 12M, YTD, ALL) with the same graph.
/// 2. Filtering by categories (All, Groceries, Dining, etc.) with real-time graph & metric recalculation.
/// 3. In-depth timeframe spending overview:
///    - Total spent in selected timeframe & category
///    - Period-over-period percentage comparison badge
///    - Average transaction size
///    - Total receipt count
///    - Daily average spend
///    - Largest single purchase with merchant name
///    - Category spending distribution with visual percentage bars
///    - Filtered receipts list matching timeframe & category
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final DashboardViewModel _viewModel;
  TimelineFilter _selectedTimeline = TimelineFilter.fourWeeks;
  final Set<String> _selectedCategories = {};

  static const List<Map<String, dynamic>> _allTimelineOptions = [
    {'filter': TimelineFilter.oneWeek, 'label': '1W'},
    {'filter': TimelineFilter.fourWeeks, 'label': '4W'},
    {'filter': TimelineFilter.thisMonth, 'label': '1M'},
    {'filter': TimelineFilter.threeMonths, 'label': '3M'},
    {'filter': TimelineFilter.sixMonths, 'label': '6M'},
    {'filter': TimelineFilter.twelveMonths, 'label': '12M'},
    {'filter': TimelineFilter.ytd, 'label': 'YTD'},
    {'filter': TimelineFilter.allTime, 'label': 'ALL'},
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _formatTimelineTitle(TimelineFilter filter) {
    switch (filter) {
      case TimelineFilter.oneWeek:
        return 'Past 7 Days';
      case TimelineFilter.fourWeeks:
        return 'Past 4 Weeks';
      case TimelineFilter.thisMonth:
        return 'This Month';
      case TimelineFilter.threeMonths:
        return 'Last 3 Months';
      case TimelineFilter.sixMonths:
        return 'Last 6 Months';
      case TimelineFilter.twelveMonths:
        return 'Last 12 Months';
      case TimelineFilter.ytd:
        return 'Year to Date';
      case TimelineFilter.allTime:
        return 'All Time';
    }
  }

  String _formatCategorySubtitle(Set<String> activeCategories) {
    if (activeCategories.isEmpty) {
      return 'All Categories';
    }
    if (activeCategories.length == 1) {
      return activeCategories.first;
    }
    if (activeCategories.length <= 3) {
      return activeCategories.join(' & ');
    }
    return '${activeCategories.length} Categories';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        _viewModel,
        ReceiptRepository.instance,
        CurrencyService.instance,
      ]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;

        final symbol = _viewModel.currentSymbol;
        final timeframeCategories =
            _viewModel.getTimeframeCategories(_selectedTimeline);
        final activeCategories = _selectedCategories
            .where((c) => timeframeCategories
                .any((tc) => tc.toLowerCase() == c.toLowerCase()))
            .toSet();

        final points = _viewModel.getMonthlySpendingHistory(
            _selectedTimeline, activeCategories);
        final overview = _viewModel.calculateTimeframeOverview(
          filter: _selectedTimeline,
          categories: activeCategories,
        );
        final matchingReceipts = _viewModel.getFilteredReceipts(
          filter: _selectedTimeline,
          categories: activeCategories,
        );

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 16, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Bar ──────────────────────────────────────────
                    Row(
                      children: [
                        NeumorphicIconBadge(
                          icon: Icons.arrow_back_rounded,
                          iconSize: 20,
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spending Analytics',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatTimelineTitle(_selectedTimeline)} • ${_formatCategorySubtitle(activeCategories)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Section 1: Category Filter Chips ─────────────────────
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        scrollDirection: Axis.horizontal,
                        itemCount: timeframeCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = timeframeCategories[index];
                          final isAll = cat == 'All';
                          final isSelected = isAll
                              ? activeCategories.isEmpty
                              : activeCategories.contains(cat);
                          final catColor = isAll
                              ? accent
                              : CategoryUtils.getCategoryColor(cat);
                          final catIcon = isAll
                              ? Icons.all_inclusive_rounded
                              : CategoryUtils.getCategoryIcon(cat);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isAll) {
                                  _selectedCategories.clear();
                                } else {
                                  if (_selectedCategories.contains(cat)) {
                                    _selectedCategories.remove(cat);
                                  } else {
                                    _selectedCategories.add(cat);
                                  }
                                }
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                depth: isSelected ? -2.5 : 2.5,
                                intensity: 0.85,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(19)),
                                color: isSelected
                                    ? catColor.withValues(alpha: 0.14)
                                    : baseColor,
                                border: NeumorphicBorder(
                                  color: isSelected
                                      ? catColor.withValues(alpha: 0.7)
                                      : Colors.transparent,
                                  width: 1.3,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    catIcon,
                                    size: 14,
                                    color: isSelected
                                        ? catColor
                                        : textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? catColor
                                          : textPrimary,
                                    ),
                                  ),
                                  if (!isAll && isSelected) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: catColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Section 2: All Timeline Options (1W · 4W · 1M · 3M · 6M · 12M · YTD · ALL)
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: -2.5,
                        intensity: 0.85,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(12)),
                        color: baseColor,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _allTimelineOptions.map((opt) {
                            final filter = opt['filter'] as TimelineFilter;
                            final label = opt['label'] as String;
                            final isSelected = filter == _selectedTimeline;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTimeline = filter;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: isSelected
                                    ? Neumorphic(
                                        style: NeumorphicStyle(
                                          depth: 2.5,
                                          intensity: 0.9,
                                          color: baseColor,
                                          boxShape:
                                              NeumorphicBoxShape.roundRect(
                                                  BorderRadius.circular(9)),
                                          border: NeumorphicBorder(
                                            color: accent
                                                .withValues(alpha: 0.35),
                                            width: 1.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 7),
                                        child: Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 7),
                                        child: Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Section 3: Interactive Line Graph Card ───────────────
                    NeumorphicCardWidget(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatTimelineTitle(_selectedTimeline)} Trend',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                '${points.length} data points',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SpendingLineGraph(
                            points: points,
                            accentColor: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            currencySymbol: symbol,
                            height: 160,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Section 4: Spending Overview Hero Card ────────────────
                    NeumorphicCardWidget(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'TOTAL SPENT THIS ${_formatTimelineTitle(_selectedTimeline).toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (activeCategories.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    ...activeCategories.take(2).map((c) {
                                      final cColor =
                                          CategoryUtils.getCategoryColor(c);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: cColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          c,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: cColor,
                                          ),
                                        ),
                                      );
                                    }),
                                    if (activeCategories.length > 2)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: textSecondary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${activeCategories.length - 2}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            overview.formattedTotal,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          if (overview.percentageChange != null) ...[
                            const SizedBox(height: 10),
                            _buildTrendPill(
                              overview.percentageChange!,
                              overview.comparisonLabel,
                              accent,
                              controller.isDarkMode,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section 5: Useful Metrics Grid (4 Cards) ─────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Avg / Transaction',
                            value: overview.formattedAverageTransaction,
                            icon: Icons.receipt_rounded,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Total Receipts',
                            value: '${overview.transactionCount}',
                            icon: Icons.tag_rounded,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Daily Average',
                            value: overview.formattedDailyAverage,
                            icon: Icons.calendar_today_rounded,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Largest Purchase',
                            value: overview.formattedHighestTransaction,
                            subtitle: overview.highestMerchant,
                            icon: Icons.stars_rounded,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Section 6: Category Breakdown Distribution ───────────
                    if (overview.categoryBreakdown.isNotEmpty) ...[
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Category Distribution',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (overview.topCategoryName != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Top: ${overview.topCategoryName} (${overview.topCategoryPercent.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: accent,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...overview.categoryBreakdown.entries.map((e) {
                              final cat = e.key;
                              final amt = e.value;
                              final pct = overview.totalSpent > 0
                                  ? (amt / overview.totalSpent)
                                  : 0.0;
                              final color =
                                  CategoryUtils.getCategoryColor(cat);
                              final formatted =
                                  CurrencyService.instance.format(amt);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  cat,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '$formatted (${(pct * 100).toStringAsFixed(1)}%)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct.clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: color
                                            .withValues(alpha: 0.15),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                color),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Section 7: Filtered Transactions List ────────────────
                    Text(
                      'Transactions in this Timeframe (${matchingReceipts.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (matchingReceipts.isEmpty) ...[
                      NeumorphicCardWidget(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 36,
                                color: textSecondary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No transactions recorded for this period.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: matchingReceipts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final receipt = matchingReceipts[index];
                          final formattedPrice = CurrencyService.instance
                              .format(receipt.amount,
                                  fromCurrencyCode: receipt.currency);

                          return ReceiptListItemWidget(
                            receipt: receipt,
                            formattedPrice: formattedPrice,
                            onTap: () => context.push('/receipt-detail',
                                extra: receipt),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendPill(double percent, String comparisonLabel, Color accent,
      bool isDarkMode) {
    final isIncrease = percent > 0;
    final isZero = percent == 0;
    final pillColor = isZero
        ? Colors.grey
        : isIncrease
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pillColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isZero
                ? Icons.remove_rounded
                : isIncrease
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
            size: 14,
            color: pillColor,
          ),
          const SizedBox(width: 5),
          Text(
            '${isIncrease ? '+' : ''}${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: pillColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            comparisonLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: pillColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return NeumorphicCardWidget(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

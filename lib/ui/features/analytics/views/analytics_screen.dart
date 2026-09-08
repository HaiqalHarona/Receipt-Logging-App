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
import '../../dashboard/views/widgets/spending_summary_card.dart';
import '../../history/views/widgets/category_filter_bottom_sheet.dart';
import '../../history/views/widgets/receipt_list_item_widget.dart';

/// Comprehensive Spending Analytics Screen.
///
/// Features:
/// 1. Category filter button (modal bottom sheet) and Timeline dropdown.
/// 2. Graph and "Total Spent This Past XXX" identical to dashboard design with embedded summary card.
/// 3. Unified Overview Metrics section with 4 indented, fixed/uniform-sized sub-sections.
/// 4. Category distribution based on amount spent, aggregating uncategorised spending to "Uncategorised".
/// 5. Filtered receipts list matching timeframe & category.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final DashboardViewModel _viewModel;
  TimelineFilter _selectedTimeline = TimelineFilter.fourWeeks;
  Set<String> _selectedCategories = {};

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
    _viewModel.setTimeline(_selectedTimeline);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

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

  void _openCategoryFilterModal() {
    final available = _viewModel
        .getTimeframeCategories(_selectedTimeline)
        .where((c) => c != 'All')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CategoryFilterBottomSheet(
        availableCategories: available,
        initialSelectedCategories: _selectedCategories,
        onApply: (newSelected) {
          setState(() {
            _selectedCategories = newSelected;
          });
        },
      ),
    );
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
        final availableCategories = _viewModel
            .getTimeframeCategories(_selectedTimeline)
            .where((c) => c != 'All')
            .toSet();
        final activeCategories =
            _selectedCategories.intersection(availableCategories);

        final points = _viewModel.getMonthlySpendingHistory(_selectedTimeline,
            activeCategories.isEmpty ? null : activeCategories);
        final overview = _viewModel.calculateTimeframeOverview(
          filter: _selectedTimeline,
          categories: activeCategories.isEmpty ? null : activeCategories,
        );
        final matchingReceipts = _viewModel.getFilteredReceipts(
          filter: _selectedTimeline,
          categories: activeCategories.isEmpty ? null : activeCategories,
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

                    const SizedBox(height: 20),

                    // ── Section 1: Category Filter Button & Timeline Dropdown ──
                    Row(
                      children: [
                        // Category Filter Button (3/4 width, 42px height)
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 42,
                            child: GestureDetector(
                              onTap: _openCategoryFilterModal,
                              child: Neumorphic(
                                style: NeumorphicStyle(
                                  depth: activeCategories.isNotEmpty ? -2 : 2.5,
                                  intensity: 0.85,
                                  boxShape: NeumorphicBoxShape.roundRect(
                                      BorderRadius.circular(12)),
                                  color: activeCategories.isNotEmpty
                                      ? accent
                                      : baseColor,
                                  border: activeCategories.isNotEmpty
                                      ? const NeumorphicBorder.none()
                                      : NeumorphicBorder(
                                          color: accent.withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_list_rounded,
                                      size: 16,
                                      color: activeCategories.isNotEmpty
                                          ? Colors.white
                                          : accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        activeCategories.isEmpty
                                            ? "Category"
                                            : "Filter (${activeCategories.length})",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: activeCategories.isNotEmpty
                                              ? Colors.white
                                              : textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Timeline Period Dropdown (1/4 width, 42px height, matching menu width)
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 42,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Neumorphic(
                                  style: NeumorphicStyle(
                                    depth: 2.5,
                                    intensity: 0.85,
                                    boxShape: NeumorphicBoxShape.roundRect(
                                        BorderRadius.circular(12)),
                                    color: baseColor,
                                    border: NeumorphicBorder(
                                      color: accent.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: ButtonTheme(
                                    alignedDropdown: true,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<TimelineFilter>(
                                        value: _selectedTimeline,
                                        isExpanded: true,
                                        isDense: true,
                                        menuWidth: constraints.maxWidth,
                                        dropdownColor: baseColor,
                                        borderRadius: BorderRadius.circular(12),
                                        icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: accent,
                                            size: 16),
                                        selectedItemBuilder: (context) {
                                          return _allTimelineOptions.map((opt) {
                                            final label =
                                                opt['label'] as String;
                                            return Center(
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList();
                                        },
                                        items: _allTimelineOptions.map((opt) {
                                          final filter =
                                              opt['filter'] as TimelineFilter;
                                          final label = opt['label'] as String;
                                          final isSelected =
                                              filter == _selectedTimeline;

                                          return DropdownMenuItem<
                                              TimelineFilter>(
                                            value: filter,
                                            child: Center(
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? accent
                                                      : textPrimary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newFilter) {
                                          if (newFilter != null) {
                                            setState(() {
                                              _selectedTimeline = newFilter;
                                              _viewModel.setTimeline(newFilter);
                                              final newAvailable = _viewModel
                                                  .getTimeframeCategories(
                                                      newFilter)
                                                  .where((c) => c != 'All')
                                                  .toSet();
                                              _selectedCategories =
                                                  _selectedCategories
                                                      .intersection(
                                                          newAvailable);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Section 2: Interactive Line Graph Card (Dashboard Design) ──
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 4,
                        intensity: 0.75,
                        boxShape: NeumorphicBoxShape.roundRect(
                            const BorderRadius.all(Radius.circular(18))),
                        color: baseColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spending Trend',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getSubtitleText(
                                            _selectedTimeline, symbol),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${points.length} data points',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SpendingLineGraph(
                              key: ValueKey(
                                  'analytics_graph_${_selectedTimeline.name}_${points.length}_${activeCategories.join(",")}'),
                              points: points,
                              accentColor: accent,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              currencySymbol: symbol,
                              height: 120,
                            ),
                            const SizedBox(height: 16),
                            SpendingSummaryCard(
                              viewModel: _viewModel,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Section 3: Overview Metrics (Single Section with Indented Cards) ──
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 4,
                        intensity: 0.75,
                        boxShape: NeumorphicBoxShape.roundRect(
                            const BorderRadius.all(Radius.circular(18))),
                        color: baseColor,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview Metrics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Row 1: 3 columns (Total Receipts, Avg / Transaction, Daily Average)
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactMetricCard(
                                  label: 'Total Receipts',
                                  value: '${overview.transactionCount}',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  baseColor: baseColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMetricCard(
                                  label: 'Avg / Transaction',
                                  value: overview.formattedAverageTransaction,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  baseColor: baseColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactMetricCard(
                                  label: 'Daily Average',
                                  value: overview.formattedDailyAverage,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  baseColor: baseColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Row 2: Full-width Largest Purchase Banner
                          _buildLargestPurchaseBanner(
                            value: overview.formattedHighestTransaction,
                            merchant: overview.highestMerchant,
                            accent: accent,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            baseColor: baseColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Section 4: Category Distribution ─────────────────────
                    if (overview.categoryBreakdown.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final sortedEntries =
                              overview.categoryBreakdown.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value));

                          return NeumorphicCardWidget(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category Distribution',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...sortedEntries.map((e) {
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
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                            backgroundColor:
                                                color.withValues(alpha: 0.15),
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
                          );
                        },
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
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final receipt = matchingReceipts[index];
                          final formattedPrice = CurrencyService.instance
                              .format(receipt.amount,
                                  fromCurrencyCode: receipt.currency);

                          return ReceiptListItemWidget(
                            receipt: receipt,
                            formattedPrice: formattedPrice,
                            onTap: () =>
                                context.push('/receipt-detail', extra: receipt),
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

  Widget _buildCompactMetricCard({
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color baseColor,
  }) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -2.5,
        intensity: 0.8,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
        color: baseColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: SizedBox(
        height: 68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.clip,
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargestPurchaseBanner({
    required String value,
    String? merchant,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color baseColor,
  }) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -2.5,
        intensity: 0.8,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
        color: baseColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Largest Purchase',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  if (merchant != null && merchant.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      merchant,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/theme/app_colors.dart';
import 'package:reciept_logging/ui/core/widgets/neu_card.dart';
import 'package:reciept_logging/ui/core/widgets/amount_display.dart';
import 'package:reciept_logging/ui/core/providers/isar_provider.dart';
import 'package:reciept_logging/data/models/receipt.dart';

enum DateFilter { thisWeek, thisMonth, last3Months, allTime }

class DashboardFilter {
  final String? category;
  final DateFilter dateFilter;
  const DashboardFilter({this.category, this.dateFilter = DateFilter.thisMonth});
  DashboardFilter copyWith({String? category, DateFilter? dateFilter, bool clearCategory = false}) {
    return DashboardFilter(
      category: clearCategory ? null : (category ?? this.category),
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }
}

final dashboardFilterProvider = StateProvider<DashboardFilter>((_) => const DashboardFilter());

final filteredReceiptsProvider = FutureProvider<List<Receipt>>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  final filter = ref.watch(dashboardFilterProvider);
  final now = DateTime.now();
  final DateTime fromDate = switch (filter.dateFilter) {
    DateFilter.thisWeek => now.subtract(const Duration(days: 7)),
    DateFilter.thisMonth => DateTime(now.year, now.month, 1),
    DateFilter.last3Months => DateTime(now.year, now.month - 3, 1),
    DateFilter.allTime => DateTime(2000),
  };
  // Fetch all receipts after fromDate, then filter by category in Dart.
  // Avoids isar_generator 3.x QueryBuilder chaining type issues.
  final all = await isar.receipts.where().findAll();
  var results = all.where((r) => r.date.isAfter(fromDate)).toList();
  if (filter.category != null) {
    results = results.where((r) => r.category == filter.category).toList();
  }
  results.sort((a, b) => b.date.compareTo(a.date));
  return results;
});

final monthlyTotalProvider = FutureProvider<double>((ref) async {
  final receipts = await ref.watch(filteredReceiptsProvider.future);
  return receipts.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
});

final categoryBreakdownProvider = FutureProvider<Map<String, double>>((ref) async {
  final receipts = await ref.watch(filteredReceiptsProvider.future);
  final breakdown = <String, double>{};
  for (final r in receipts) {
    breakdown[r.category] = (breakdown[r.category] ?? 0) + r.totalAmount;
  }
  return Map.fromEntries(breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _filterLabel(DateFilter f) => switch (f) {
    DateFilter.thisWeek => 'This Week',
    DateFilter.thisMonth => 'This Month',
    DateFilter.last3Months => 'Last 3 Months',
    DateFilter.allTime => 'All Time',
  };

  String _filterHumanDescription(DateFilter f) => switch (f) {
    DateFilter.thisWeek => 'Past 7 days of expenses',
    DateFilter.thisMonth => 'Current month expenses',
    DateFilter.last3Months => 'Expenses over the last 90 days',
    DateFilter.allTime => 'All time recorded expenses',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(filteredReceiptsProvider);
    final totalAsync = ref.watch(monthlyTotalProvider);
    final categoryAsync = ref.watch(categoryBreakdownProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final primaryColor = AppTheme.textPrimaryOf(context);
    final secondaryColor = AppTheme.textSecondaryOf(context);

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColorOf(context),
        floatingActionButton: GestureDetector(
          onTap: () => context.go('/scanner'),
          child: Neumorphic(
            style: AppTheme.fabStyle,
            child: const SizedBox(
              width: 64, height: 64,
              child: Center(child: Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28)),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dashboard', style: AppTheme.displayLarge.copyWith(fontSize: 26, color: primaryColor)),
                        Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                      ]),
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: Neumorphic(
                          style: const NeumorphicStyle(depth: 5, boxShape: NeumorphicBoxShape.circle()),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.settings_rounded, size: 22, color: secondaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Total spending card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: NeuCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_filterLabel(filter.dateFilter).toUpperCase(),
                                style: AppTheme.labelSmall),
                            const SizedBox(height: 2),
                            Text(_filterHumanDescription(filter.dateFilter),
                                style: AppTheme.bodyMedium.copyWith(fontSize: 12, color: secondaryColor)),
                            const SizedBox(height: 8),
                            totalAsync.when(
                              loading: () => const SizedBox(height: 40,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                              error: (_, __) => const AmountDisplay(amount: 0.0, large: true),
                              data: (total) => AmountDisplay(amount: total, large: true),
                            ),
                          ]),
                          Neumorphic(
                            style: NeumorphicStyle(
                              depth: 6,
                              color: AppTheme.accentColor.withValues(alpha: 0.1),
                              boxShape: const NeumorphicBoxShape.circle(),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(14),
                              child: Icon(Icons.account_balance_wallet_rounded,
                                  color: AppTheme.accentColor, size: 28),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      receiptsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (receipts) => Wrap(spacing: 12, children: [
                          _StatPill(
                            label: 'Receipts', value: '${receipts.length}',
                            icon: Icons.receipt_long_rounded,
                          ),
                          if (receipts.isNotEmpty) _StatPill(
                            label: 'Avg',
                            value: NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(
                              receipts.fold(0.0, (s, r) => s + r.totalAmount) / receipts.length,
                            ),
                            icon: Icons.trending_up_rounded,
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              // Date filter chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Time Range', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: DateFilter.values.map((f) {
                          final isSel = filter.dateFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => ref.read(dashboardFilterProvider.notifier).state =
                                  filter.copyWith(dateFilter: f),
                              child: Neumorphic(
                                style: AppTheme.chipStyle.copyWith(
                                  depth: isSel ? -3 : 4,
                                  color: isSel ? AppTheme.accentColor.withValues(alpha: 0.15) : null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Text(_filterLabel(f), style: AppTheme.bodyMedium.copyWith(
                                    color: isSel ? AppTheme.accentColor : secondaryColor,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                  )),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ]),
                ),
              ),
              // Category breakdown
              SliverToBoxAdapter(
                child: categoryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (breakdown) => breakdown.isEmpty ? const SizedBox.shrink() :
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: NeuCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('By Category', style: AppTheme.titleLarge.copyWith(color: primaryColor)),
                            const SizedBox(height: 16),
                            ...breakdown.entries.take(5).map((entry) {
                              final maxVal = breakdown.values.first;
                              final fraction = maxVal > 0 ? entry.value / maxVal : 0.0;
                              final color = AppColors.getCategoryColor(entry.key);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Container(width: 10, height: 10,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Text(entry.key, style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                                      ]),
                                      Text(
                                        NumberFormat.currency(symbol: '\$').format(entry.value),
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600, color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Neumorphic(
                                    style: AppTheme.insetStyle.copyWith(
                                      depth: -3,
                                      boxShape: NeumorphicBoxShape.roundRect(
                                          const BorderRadius.all(Radius.circular(8))),
                                    ),
                                    child: SizedBox(
                                      height: 8,
                                      child: FractionallySizedBox(
                                        widthFactor: fraction.clamp(0.02, 1.0),
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: color, borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                          ]),
                        ),
                      ),
                ),
              ),
              // Timeline header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt Timeline', style: AppTheme.titleLarge.copyWith(color: primaryColor)),
                      receiptsAsync.maybeWhen(
                        data: (r) => Text('${r.length} receipts', style: AppTheme.bodyMedium.copyWith(color: secondaryColor)),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              // Receipt list
              receiptsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: NeuCard(
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 36, color: AppTheme.warningColor),
                          const SizedBox(height: 12),
                          Text('Unable to load receipts',
                              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: primaryColor)),
                          const SizedBox(height: 6),
                          Text('Storage connection initializing. Tap retry to refresh.',
                              style: AppTheme.bodyMedium.copyWith(color: secondaryColor), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          NeumorphicButton(
                            onPressed: () => ref.invalidate(filteredReceiptsProvider),
                            style: AppTheme.buttonStyle,
                            child: Text('Retry', style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (receipts) => receipts.isEmpty
                    ? SliverToBoxAdapter(child: _EmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: _ReceiptCard(
                              receipt: receipts[index],
                              onTap: () => context.push('/dashboard/receipt/${receipts[index].id}'),
                            ),
                          ),
                          childCount: receipts.length,
                        ),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onTap;
  const _ReceiptCard({required this.receipt, required this.onTap});

  IconData _categoryIcon(String category) => switch (category) {
    'Food & Dining' => Icons.restaurant_rounded,
    'Shopping' => Icons.shopping_bag_rounded,
    'Transportation' => Icons.directions_car_rounded,
    'Entertainment' => Icons.movie_rounded,
    'Healthcare' => Icons.local_hospital_rounded,
    'Utilities' => Icons.bolt_rounded,
    _ => Icons.receipt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(receipt.category);
    final primaryColor = AppTheme.textPrimaryOf(context);
    final secondaryColor = AppTheme.textSecondaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Neumorphic(
        style: AppTheme.cardStyle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Neumorphic(
              style: NeumorphicStyle(
                depth: 4, color: color.withValues(alpha: 0.15),
                boxShape: const NeumorphicBoxShape.circle(),
              ),
              child: SizedBox(
                width: 48, height: 48,
                child: Center(child: Icon(_categoryIcon(receipt.category), color: color, size: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(receipt.merchantName,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: primaryColor),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(DateFormat('MMM d').format(receipt.date),
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12, color: secondaryColor)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(receipt.category, style: AppTheme.labelSmall.copyWith(
                      color: color, fontWeight: FontWeight.w600,
                    )),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AmountDisplay(amount: receipt.totalAmount),
              if (!receipt.isSynced) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_rounded, size: 10, color: AppTheme.textMuted),
                  const SizedBox(width: 2),
                  Text('Local', style: AppTheme.labelSmall),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      style: AppTheme.chipStyle.copyWith(depth: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppTheme.accentColor),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTheme.labelSmall),
            Text(value, style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context), fontSize: 13,
            )),
          ]),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Neumorphic(
          style: const NeumorphicStyle(
            depth: 8, shape: NeumorphicShape.concave, boxShape: NeumorphicBoxShape.circle(),
          ),
          child: const SizedBox(
            width: 100, height: 100,
            child: Center(child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textMuted)),
          ),
        ),
        const SizedBox(height: 24),
        Text('No receipts yet', style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        Text('Tap the scan button to capture your first receipt',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryOf(context)), textAlign: TextAlign.center),
      ]),
    );
  }
}

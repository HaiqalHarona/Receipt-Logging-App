// File: lib/ui/features/history/views/history_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../view_models/history_view_model.dart';
import 'widgets/category_filter_bottom_sheet.dart';
import 'widgets/receipt_list_item_widget.dart';
import '../../../../services/app_logger_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final HistoryViewModel _viewModel = HistoryViewModel();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('UI', 'HistoryScreen initialized');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _openFilterModal() {
    AppLogger.info('UI', 'User tapped Category Filter button');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CategoryFilterBottomSheet(
        availableCategories: _viewModel.availableCategories,
        initialSelectedCategories: _viewModel.selectedCategories,
        onApply: (selected) {
          AppLogger.info(
              'UI', 'User applied category filters: ${selected.toList()}');
          _viewModel.setCategories(selected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([AppThemeController.instance, _viewModel]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        final list = _viewModel.receipts;
        final selectedCats = _viewModel.selectedCategories;
        final sortField = _viewModel.sortField;
        final sortAsc = _viewModel.sortAscending;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fixed Top Controls Block (Header, Search, Filters, Sort) ──
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 24, right: 24, top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Receipt History",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "All logged transactions (${list.length} records)",
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 1. Indented Search Bar
                        Neumorphic(
                          style: NeumorphicStyle(
                            depth: -3,
                            intensity: 0.8,
                            color: NeumorphicTheme.baseColor(context),
                            boxShape: NeumorphicBoxShape.roundRect(
                                BorderRadius.circular(14)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: textSecondary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: InputDecoration(
                                    hintText: "Search merchant, item, date...",
                                    hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: textSecondary.withValues(
                                            alpha: 0.7)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (val) =>
                                      _viewModel.setSearchQuery(val),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    AppLogger.info(
                                        'UI', 'User cleared search query');
                                    _searchController.clear();
                                    _viewModel.setSearchQuery('');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: textSecondary, size: 18),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 2. Uniform Action Controls Row (Category, Name "A", Amount "$", Date "D")
                        Row(
                          children: [
                            // Category Filter Button
                            Expanded(
                              child: GestureDetector(
                                onTap: _openFilterModal,
                                child: Neumorphic(
                                  style: NeumorphicStyle(
                                    depth: selectedCats.isNotEmpty ? -2 : 3,
                                    intensity: 0.8,
                                    color: selectedCats.isNotEmpty
                                        ? accent
                                        : NeumorphicTheme.baseColor(context),
                                    boxShape: NeumorphicBoxShape.roundRect(
                                        BorderRadius.circular(12)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.filter_list_rounded,
                                        size: 16,
                                        color: selectedCats.isNotEmpty
                                            ? Colors.white
                                            : textPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        selectedCats.isEmpty
                                            ? "Category"
                                            : "Filter (${selectedCats.length})",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: selectedCats.isNotEmpty
                                              ? Colors.white
                                              : textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Uniform Sort Button Helper
                            _buildUniformSortButton(
                              context: context,
                              label: "A",
                              field: HistorySortField.name,
                              currentField: sortField,
                              sortAsc: sortAsc,
                              accent: accent,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            const SizedBox(width: 6),

                            _buildUniformSortButton(
                              context: context,
                              label: "\$",
                              field: HistorySortField.amount,
                              currentField: sortField,
                              sortAsc: sortAsc,
                              accent: accent,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            const SizedBox(width: 6),

                            _buildUniformSortButton(
                              context: context,
                              label: "D",
                              field: HistorySortField.date,
                              currentField: sortField,
                              sortAsc: sortAsc,
                              accent: accent,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // ── Independently Scrollable Receipt Records List ─────────────
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 48),
                              child: Text(
                                "No matching receipts found.\nTry clearing your search or category filters!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: textSecondary, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                                left: 24, right: 24, bottom: 120),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final receipt = list[index];
                              final formattedPrice =
                                  _viewModel.formatReceiptPrice(receipt);

                              return ReceiptListItemWidget(
                                receipt: receipt,
                                formattedPrice: formattedPrice,
                                onTap: () {
                                  AppLogger.info('UI',
                                      'User tapped receipt item: ${receipt.id}');
                                  context.push('/receipt-detail',
                                      extra: receipt);
                                },
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                accent: accent,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds a uniform sort toggle button with single-character label and direction arrow.
  Widget _buildUniformSortButton({
    required BuildContext context,
    required String label,
    required HistorySortField field,
    required HistorySortField currentField,
    required bool sortAsc,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isActive = currentField == field;

    return GestureDetector(
      onTap: () => _viewModel.toggleSort(field),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: isActive ? -2 : 3,
          intensity: 0.8,
          color: isActive ? accent : NeumorphicTheme.baseColor(context),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SizedBox(
          height: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                isActive
                    ? (sortAsc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: isActive ? Colors.white : textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

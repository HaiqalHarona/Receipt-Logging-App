// File: lib/ui/features/history/views/history_screen.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../view_models/history_view_model.dart';
import 'widgets/category_filter_bottom_sheet.dart';
import 'widgets/receipt_list_item_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryViewModel _viewModel = HistoryViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CategoryFilterBottomSheet(
        availableCategories: _viewModel.availableCategories,
        initialSelectedCategories: _viewModel.selectedCategories,
        onApply: (selected) {
          _viewModel.setCategories(selected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            bottomNavigationBar: const AppBottomNavBar(currentPath: '/history'),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
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

                    // 1. Indented Search Bar with 0.5s Debounce (Height extended by 10%)
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: -3,
                        intensity: 0.8,
                        color: NeumorphicTheme.baseColor(context),
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(fontSize: 14, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: "Search merchant, item, date...",
                                hintStyle: TextStyle(fontSize: 14, color: textSecondary.withValues(alpha: 0.7)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) => _viewModel.setSearchQuery(val),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _viewModel.setSearchQuery('');
                              },
                              child: Icon(Icons.close_rounded, color: textSecondary, size: 18),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Filter & Sort Action Controls Row (Category, Name, Amount, Date)
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
                                color: selectedCats.isNotEmpty ? accent : NeumorphicTheme.baseColor(context),
                                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    size: 16,
                                    color: selectedCats.isNotEmpty ? Colors.white : textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedCats.isEmpty
                                        ? "Category"
                                        : "Filter (${selectedCats.length})",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: selectedCats.isNotEmpty ? Colors.white : textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Sort Name (A) Button
                        GestureDetector(
                          onTap: () => _viewModel.toggleSort(HistorySortField.name),
                          child: Neumorphic(
                            style: NeumorphicStyle(
                              depth: sortField == HistorySortField.name ? -2 : 3,
                              intensity: 0.8,
                              color: sortField == HistorySortField.name ? accent : NeumorphicTheme.baseColor(context),
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  "A",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: sortField == HistorySortField.name ? Colors.white : textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  sortField == HistorySortField.name
                                      ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: sortField == HistorySortField.name ? Colors.white : textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Sort Amount ($) Button
                        GestureDetector(
                          onTap: () => _viewModel.toggleSort(HistorySortField.amount),
                          child: Neumorphic(
                            style: NeumorphicStyle(
                              depth: sortField == HistorySortField.amount ? -2 : 3,
                              intensity: 0.8,
                              color: sortField == HistorySortField.amount ? accent : NeumorphicTheme.baseColor(context),
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  "\$",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: sortField == HistorySortField.amount ? Colors.white : textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  sortField == HistorySortField.amount
                                      ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: sortField == HistorySortField.amount ? Colors.white : textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Sort Date (📅) Button
                        GestureDetector(
                          onTap: () => _viewModel.toggleSort(HistorySortField.date),
                          child: Neumorphic(
                            style: NeumorphicStyle(
                              depth: sortField == HistorySortField.date ? -2 : 3,
                              intensity: 0.8,
                              color: sortField == HistorySortField.date ? accent : NeumorphicTheme.baseColor(context),
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: sortField == HistorySortField.date ? Colors.white : textPrimary,
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  sortField == HistorySortField.date
                                      ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                      : Icons.unfold_more_rounded,
                                  size: 14,
                                  color: sortField == HistorySortField.date ? Colors.white : textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. Receipt List / Empty State
                    if (list.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            "No matching receipts found.\nTry clearing your search or category filters!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final receipt = list[index];
                          final formattedPrice = _viewModel.formatReceiptPrice(receipt);

                          return ReceiptListItemWidget(
                            receipt: receipt,
                            formattedPrice: formattedPrice,
                            onTap: () => context.push('/receipt-detail', extra: receipt),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// File: lib/ui/features/history/views/widgets/category_filter_bottom_sheet.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../core/theme/theme_controller.dart';

/// Modal bottom sheet for multi-select category filtering on HistoryScreen.
class CategoryFilterBottomSheet extends StatefulWidget {
  final List<String> availableCategories;
  final Set<String> initialSelectedCategories;
  final ValueChanged<Set<String>> onApply;

  const CategoryFilterBottomSheet({
    super.key,
    required this.availableCategories,
    required this.initialSelectedCategories,
    required this.onApply,
  });

  @override
  State<CategoryFilterBottomSheet> createState() => _CategoryFilterBottomSheetState();
}

class _CategoryFilterBottomSheetState extends State<CategoryFilterBottomSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelectedCategories);
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_selected.contains(cat)) {
        _selected.remove(cat);
      } else {
        _selected.add(cat);
      }
    });
  }

  void _reset() {
    setState(() {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final baseColor = controller.currentBaseColor;

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Filter by Category",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              TextButton(
                onPressed: _reset,
                child: Text(
                  "Reset All",
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Chips Grid/Wrap
          if (widget.availableCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No categories found.",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: widget.availableCategories.map((cat) {
                final isSelected = _selected.contains(cat);
                return GestureDetector(
                  onTap: () => _toggleCategory(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: Neumorphic(
                      style: NeumorphicStyle(
                        depth: isSelected ? -3 : 3,
                        intensity: 0.8,
                        color: isSelected ? accent : baseColor,
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            size: 16,
                            color: isSelected ? Colors.white : textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: NeumorphicButton(
              onPressed: () {
                widget.onApply(_selected);
                Navigator.of(context).pop();
              },
              style: NeumorphicStyle(
                depth: 4,
                intensity: 0.85,
                color: accent,
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Center(
                child: Text(
                  "Apply Filter",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

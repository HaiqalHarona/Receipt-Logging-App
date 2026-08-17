// File: lib/ui/features/verification/views/widgets/category_multi_select_bottom_sheet.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../data/repositories/receipt_repository.dart';
import '../../../../../services/category_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/category_utils.dart';

/// Modal Bottom Sheet supporting category multi-selection and inline
/// creation of new custom categories (max 8 custom categories).
class CategoryMultiSelectBottomSheet extends StatefulWidget {
  final List<String> initialSelected;

  const CategoryMultiSelectBottomSheet({
    super.key,
    required this.initialSelected,
  });

  /// Static helper to display the bottom sheet and return selected categories.
  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> initialSelected,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: CategoryMultiSelectBottomSheet(
          initialSelected: initialSelected,
        ),
      ),
    );
  }

  @override
  State<CategoryMultiSelectBottomSheet> createState() =>
      _CategoryMultiSelectBottomSheetState();
}

class _CategoryMultiSelectBottomSheetState
    extends State<CategoryMultiSelectBottomSheet> {
  static const bool _enableCategoryCreation = true;

  static const List<String> _defaultCategories = [
    'Groceries',
    'Dining',
    'Transport',
    'Shopping',
    'Electronics',
    'General',
  ];

  static const List<Color> _presetColors = [
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF3B82F6), // Electric Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF43F5E), // Rose Pink
    Color(0xFFF97316), // Coral Orange
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Hot Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF84CC16), // Lime Green
    Color(0xFFEAB308), // Sun Yellow
    Color(0xFFA855F7), // Rich Orchid
    Color(0xFFD946EF), // Magenta
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF22C55E), // Vibrant Green
    Color(0xFFEF4444), // Crimson Red
    Color(0xFF64748B), // Slate Blue
    Color(0xFF78716C), // Warm Stone
    Color(0xFFD97706), // Ochre Bronze
    Color(0xFF059669), // Forest Jade
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF7C3AED), // Deep Violet
    Color(0xFFBE123C), // Ruby Red
    Color(0xFF0D9488), // Deep Teal
    Color(0xFF4F46E5), // Deep Indigo
    Color(0xFFDB2777), // Berry Pink
    Color(0xFFCA8A04), // Mustard Gold
    Color(0xFF15803D), // Pine Green
    Color(0xFF475569), // Charcoal Slate
  ];

  static const List<IconData> _presetIcons = [
    Icons.local_grocery_store_rounded,
    Icons.fastfood_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.devices_rounded,
    Icons.movie_rounded,
    Icons.fitness_center_rounded,
    Icons.medical_services_rounded,
    Icons.card_giftcard_rounded,
    Icons.local_cafe_rounded,
    Icons.home_rounded,
    Icons.work_rounded,
    Icons.flight_rounded,
    Icons.hotel_rounded,
    Icons.local_gas_station_rounded,
    Icons.pets_rounded,
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.spa_rounded,
    Icons.cleaning_services_rounded,
    Icons.build_rounded,
    Icons.receipt_long_rounded,
    Icons.wifi_rounded,
    Icons.child_care_rounded,
    Icons.local_bar_rounded,
    Icons.directions_bus_rounded,
    Icons.savings_rounded,
    Icons.category_rounded,
  ];

  late Set<String> _selectedCategories;
  bool _isAddingNew = false;
  bool _isEditingCategories = false;

  final TextEditingController _newCatNameController = TextEditingController();
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  String? _creationError;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(
      widget.initialSelected
          .map((s) => CategoryUtils.sanitize(s).trim())
          .where((s) => s.isNotEmpty),
    );
    CategoryService.instance.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _newCatNameController.dispose();
    super.dispose();
  }

  List<String> get _allCategories {
    final customNames =
        CategoryService.instance.customCategories.map((c) => c.name).toList();
    final combined = <String>[..._defaultCategories];
    for (final custom in customNames) {
      if (!combined.contains(custom)) {
        combined.add(custom);
      }
    }
    return combined;
  }

  Future<void> _confirmAndDeleteCategory(String cat) async {
    final baseColor = NeumorphicTheme.baseColor(context);
    final textPrimary = AppThemeController.instance.textColor;
    final textSecondary = AppThemeController.instance.secondaryTextColor;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: baseColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Category',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$cat"? This will untag it from all receipts.',
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: NeumorphicButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: NeumorphicStyle(
                    depth: 2,
                    intensity: 0.85,
                    color: baseColor,
                    boxShape:
                        NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeumorphicButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: NeumorphicStyle(
                    depth: 3,
                    intensity: 0.85,
                    color: Colors.redAccent,
                    boxShape:
                        NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: const Center(
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedCategories.remove(cat);
      });
      await CategoryService.instance.removeCategory(cat);
      await ReceiptRepository.instance.removeCategoryFromAllReceipts(cat);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleSaveNewCategory() async {
    final name = _newCatNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _creationError = 'Category name cannot be empty.');
      return;
    }

    final colorVal = _presetColors[_selectedColorIndex].toARGB32();
    final iconCodePoint = _presetIcons[_selectedIconIndex].codePoint;

    final success = await CategoryService.instance
        .addCategory(name, colorVal, iconCodePoint);
    if (!success) {
      setState(() {
        if (CategoryService.instance.isMaxReached) {
          _creationError =
              'Maximum ${CategoryService.maxCustomCategories} custom categories reached.';
        } else {
          _creationError = 'A category with this name already exists.';
        }
      });
      return;
    }

    // Auto select newly created category
    final cleanName = CategoryUtils.sanitize(name).trim();
    setState(() {
      _selectedCategories.add(cleanName);
      _isAddingNew = false;
      _newCatNameController.clear();
      _creationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = NeumorphicTheme.baseColor(context);
    final accent = AppThemeController.instance.accentColor;
    final textPrimary = AppThemeController.instance.textColor;
    final textSecondary = AppThemeController.instance.secondaryTextColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isAddingNew ? 'Create Custom Category' : 'Select Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                if (_isAddingNew)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAddingNew = false;
                        _creationError = null;
                      });
                    },
                    child: Icon(Icons.close_rounded,
                        color: textSecondary, size: 22),
                  )
                else
                  Text(
                    '${_selectedCategories.length} selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Body View Switcher
          Flexible(
            child: SingleChildScrollView(
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: _isAddingNew
                  ? _buildAddCategoryView(
                      baseColor, accent, textPrimary, textSecondary)
                  : _buildMultiSelectListView(
                      baseColor, accent, textPrimary, textSecondary),
            ),
          ),

          const SizedBox(height: 16),

          // Bottom Action Button Bar
          if (!_isAddingNew)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: NeumorphicButton(
                      onPressed: () {
                        Navigator.of(context).pop(_selectedCategories.toList());
                      },
                      style: NeumorphicStyle(
                        depth: 4,
                        intensity: 0.85,
                        color: accent,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(14)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// View 1: Multi-Select Category List View
  Widget _buildMultiSelectListView(
    Color baseColor,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    final customCount = CategoryService.instance.customCategoryCount;
    final isMaxReached = CategoryService.instance.isMaxReached;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Items Grid / List
        ..._allCategories.map((cat) {
          final isSelected = _selectedCategories.contains(cat);
          final catColor = CategoryUtils.getCategoryColor(cat);
          final catIcon = CategoryUtils.getCategoryIcon(cat);
          final isCustom =
              CategoryService.instance.findCustomCategory(cat) != null;

          return Padding(
            padding:
                const EdgeInsets.only(bottom: 12, left: 2, right: 2, top: 2),
            child: GestureDetector(
              onTap: _isEditingCategories
                  ? (isCustom ? () => _confirmAndDeleteCategory(cat) : null)
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedCategories.remove(cat);
                        } else {
                          _selectedCategories.add(cat);
                        }
                      });
                    },
              child: Neumorphic(
                style: NeumorphicStyle(
                  depth: _isEditingCategories
                      ? (isCustom ? 2 : 0)
                      : (isSelected ? -2 : 3),
                  intensity: 0.85,
                  color: _isEditingCategories
                      ? (isCustom
                          ? baseColor
                          : baseColor.withValues(alpha: 0.5))
                      : (isSelected
                          ? accent.withValues(alpha: 0.15)
                          : baseColor),
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(catIcon, size: 18, color: catColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: _isEditingCategories && !isCustom
                              ? textSecondary.withValues(alpha: 0.5)
                              : (isSelected ? accent : textPrimary),
                        ),
                      ),
                    ),
                    if (_isEditingCategories)
                      if (isCustom)
                        GestureDetector(
                          onTap: () => _confirmAndDeleteCategory(cat),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  Colors.red.shade900.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 20)
                    else
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? accent
                            : textSecondary.withValues(alpha: 0.4),
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),

        // 2-Column Action Buttons Row: [Col 1: Edit Categories] [Col 2: Add New (X/8)]
        if (_enableCategoryCreation) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                // Col-1: Edit Categories
                Expanded(
                  child: NeumorphicButton(
                    onPressed: () {
                      setState(() {
                        _isEditingCategories = !_isEditingCategories;
                      });
                    },
                    style: NeumorphicStyle(
                      depth: _isEditingCategories ? -2 : 3,
                      intensity: 0.85,
                      color: _isEditingCategories
                          ? accent.withValues(alpha: 0.15)
                          : baseColor,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(14)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditingCategories
                              ? Icons.check_circle_outline_rounded
                              : Icons.edit_rounded,
                          size: 16,
                          color: _isEditingCategories ? accent : textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _isEditingCategories
                                ? 'Done Editing'
                                : 'Edit Categories',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color:
                                  _isEditingCategories ? accent : textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col-2: Add New Category
                Expanded(
                  child: NeumorphicButton(
                    onPressed: isMaxReached
                        ? null
                        : () {
                            setState(() {
                              _isAddingNew = true;
                              _isEditingCategories = false;
                              _creationError = null;
                            });
                          },
                    style: NeumorphicStyle(
                      depth: isMaxReached ? -4 : 3,
                      intensity: 0.85,
                      color: isMaxReached
                          ? baseColor.withValues(alpha: 0.5)
                          : baseColor,
                      boxShape: NeumorphicBoxShape.roundRect(
                          BorderRadius.circular(14)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 16,
                          color: isMaxReached
                              ? textSecondary.withValues(alpha: 0.5)
                              : accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isMaxReached
                                ? 'Max ($customCount/${CategoryService.maxCustomCategories})'
                                : 'Add New ($customCount/${CategoryService.maxCustomCategories})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isMaxReached
                                  ? textSecondary.withValues(alpha: 0.5)
                                  : accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// View 2: Inline Custom Category Creation View
  Widget _buildAddCategoryView(
    Color baseColor,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_creationError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade700, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _creationError!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Category Name Input
        Text(
          'Category Name',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
        ),
        const SizedBox(height: 6),
        Neumorphic(
          style: NeumorphicStyle(
            depth: -3,
            intensity: 0.85,
            color: baseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
          ),
          child: TextField(
            controller: _newCatNameController,
            style: TextStyle(
                color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g., Subscriptions, Books, Pet Care',
              hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.5), fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
            onChanged: (_) {
              if (_creationError != null) setState(() => _creationError = null);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Color Presets Grid (30 Colors)
        Text(
          'Select Theme Color',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: List.generate(_presetColors.length, (index) {
            final color = _presetColors[index];
            final isSelected = index == _selectedColorIndex;

            return GestureDetector(
              onTap: () => setState(() => _selectedColorIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: textPrimary, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // Icon Presets Grid (30 Icons)
        Text(
          'Select Icon',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_presetIcons.length, (index) {
            final icon = _presetIcons[index];
            final isSelected = index == _selectedIconIndex;
            final currentColor = _presetColors[_selectedColorIndex];

            return GestureDetector(
              onTap: () => setState(() => _selectedIconIndex = index),
              child: Neumorphic(
                style: NeumorphicStyle(
                  depth: isSelected ? -2 : 3,
                  intensity: 0.85,
                  color: isSelected
                      ? currentColor.withValues(alpha: 0.2)
                      : baseColor,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? currentColor : textSecondary,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Save & Cancel Action Buttons
        Row(
          children: [
            Expanded(
              child: NeumorphicButton(
                onPressed: () {
                  setState(() {
                    _isAddingNew = false;
                    _creationError = null;
                  });
                },
                style: NeumorphicStyle(
                  depth: 2,
                  intensity: 0.85,
                  color: baseColor,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeumorphicButton(
                onPressed: _handleSaveNewCategory,
                style: NeumorphicStyle(
                  depth: 4,
                  intensity: 0.85,
                  color: accent,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Center(
                  child: Text(
                    'Save Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

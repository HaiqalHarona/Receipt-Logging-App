import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/ui/core/theme/app_colors.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getCategoryColor(category);
    return GestureDetector(
      onTap: onTap,
      child: Neumorphic(
        style: AppTheme.chipStyle.copyWith(
          color: isSelected ? color.withValues(alpha: 0.15) : null,
          depth: isSelected ? -3 : 4,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: AppTheme.bodyMedium.copyWith(
                  color: isSelected ? color : AppTheme.textSecondaryOf(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

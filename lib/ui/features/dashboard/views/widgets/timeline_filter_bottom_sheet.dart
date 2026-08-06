// File: lib/ui/features/dashboard/views/widgets/timeline_filter_bottom_sheet.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../view_models/dashboard_view_model.dart';

/// Modal bottom sheet pop-up for choosing spending graph timeline.
class TimelineFilterBottomSheet extends StatelessWidget {
  final TimelineFilter activeFilter;
  final ValueChanged<TimelineFilter> onSelect;

  const TimelineFilterBottomSheet({
    super.key,
    required this.activeFilter,
    required this.onSelect,
  });

  static const List<_TimelineOption> _options = [
    _TimelineOption(filter: TimelineFilter.threeMonths, label: '3mo', subtitle: 'Last 3 Months'),
    _TimelineOption(filter: TimelineFilter.sixMonths, label: '6mo', subtitle: 'Last 6 Months'),
    _TimelineOption(filter: TimelineFilter.ytd, label: 'YTD', subtitle: 'Year to Date'),
    _TimelineOption(filter: TimelineFilter.twelveMonths, label: '12mo', subtitle: 'Last 12 Months'),
    _TimelineOption(filter: TimelineFilter.allTime, label: 'All', subtitle: 'All-time (since first receipt)'),
  ];

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
                "Select Timeline",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded, color: textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical Option Tiles
          ..._options.map((opt) {
            final isSelected = opt.filter == activeFilter;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  onSelect(opt.filter);
                  Navigator.of(context).pop();
                },
                child: Neumorphic(
                  style: NeumorphicStyle(
                    depth: isSelected ? -2 : 3,
                    intensity: 0.8,
                    color: isSelected ? accent : baseColor,
                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withValues(alpha: 0.2) : accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          opt.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineOption {
  final TimelineFilter filter;
  final String label;
  final String subtitle;

  const _TimelineOption({
    required this.filter,
    required this.label,
    required this.subtitle,
  });
}

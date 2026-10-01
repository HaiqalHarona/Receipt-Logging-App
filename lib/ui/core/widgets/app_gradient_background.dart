// File: lib/ui/core/widgets/app_gradient_background.dart

import 'package:flutter/widgets.dart';
import '../theme/theme_controller.dart';

/// Full-canvas subtle gradient background widget that illuminates screens with
/// a natural vertical lighting falloff (lighter top to darker bottom) across all presets.
class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppThemeController.instance.backgroundGradient,
          ),
          child: child,
        );
      },
    );
  }
}

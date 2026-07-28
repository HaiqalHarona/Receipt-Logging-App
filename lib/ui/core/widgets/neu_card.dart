import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final NeumorphicStyle? style;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.style,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Neumorphic(
      style: style ?? AppTheme.cardStyle,
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }
}

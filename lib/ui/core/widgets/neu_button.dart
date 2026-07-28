import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

class NeuButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final NeumorphicStyle? style;
  final EdgeInsets? padding;
  final bool isAccent;

  const NeuButton({
    super.key,
    required this.child,
    this.onTap,
    this.style,
    this.padding,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicButton(
      onPressed: onTap,
      style: style ?? (isAccent
          ? AppTheme.buttonStyle.copyWith(color: AppTheme.accentColor)
          : AppTheme.buttonStyle),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: child,
    );
  }
}

// File: lib/ui/core/widgets/fading_edge_scroll_view.dart

import 'package:flutter/material.dart';

/// Wraps scrollable content with an opacity gradient mask on top and bottom.
///
/// Prevents harsh horizontal clipping lines on outer neumorphic shadows while
/// stopping scrolled items from bleeding over preceding fixed headers/controls.
class FadingEdgeScrollView extends StatelessWidget {
  final Widget child;
  final double fadeHeightTop;
  final double fadeHeightBottom;
  final bool fadeTop;
  final bool fadeBottom;

  const FadingEdgeScrollView({
    super.key,
    required this.child,
    this.fadeHeightTop = 20.0,
    this.fadeHeightBottom = 28.0,
    this.fadeTop = true,
    this.fadeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        if (bounds.height <= 0) {
          return const LinearGradient(
            colors: [Colors.black, Colors.black],
          ).createShader(bounds);
        }

        final topFraction =
            (fadeTop ? (fadeHeightTop / bounds.height) : 0.0).clamp(0.0, 0.4);
        final bottomFraction = (fadeBottom
                ? (1.0 - (fadeHeightBottom / bounds.height))
                : 1.0)
            .clamp(0.6, 1.0);

        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            if (fadeTop) Colors.transparent else Colors.black,
            Colors.black,
            Colors.black,
            if (fadeBottom) Colors.transparent else Colors.black,
          ],
          stops: [
            0.0,
            topFraction,
            bottomFraction,
            1.0,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

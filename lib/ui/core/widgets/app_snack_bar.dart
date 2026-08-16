// File: lib/ui/core/widgets/app_snack_bar.dart

import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// Reusable custom SnackBar component with rounded corners,
/// right-side close 'x' icon, and a bottom border statusline timer progress line.
class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
    Widget? customIcon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final controller = AppThemeController.instance;
    final backgroundColor = isError
        ? Colors.red.shade900
        : (controller.isDarkMode
            ? const Color(0xFF2C2C2E)
            : const Color(0xFF1C1C1E));
    final timerColor = isError ? Colors.redAccent : controller.accentColor;

    final snackBar = SnackBar(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      content: _AppSnackBarWidget(
        message: message,
        duration: duration,
        backgroundColor: backgroundColor,
        timerColor: timerColor,
        isError: isError,
        customIcon: customIcon,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

class _AppSnackBarWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final Color backgroundColor;
  final Color timerColor;
  final bool isError;
  final Widget? customIcon;

  const _AppSnackBarWidget({
    required this.message,
    required this.duration,
    required this.backgroundColor,
    required this.timerColor,
    required this.isError,
    this.customIcon,
  });

  @override
  State<_AppSnackBarWidget> createState() => _AppSnackBarWidgetState();
}

class _AppSnackBarWidgetState extends State<_AppSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..reverse(from: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: widget.backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 14, right: 6, top: 10, bottom: 10),
              child: Row(
                children: [
                  widget.customIcon ??
                      Icon(
                        widget.isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: widget.timerColor,
                        size: 20,
                      ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () =>
                        ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Statusline Timer Progress Line
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _controller.value.clamp(0.0, 1.0),
                    child: Container(
                      height: 3,
                      color: widget.timerColor,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

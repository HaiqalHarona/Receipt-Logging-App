import 'dart:async';

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    // Navigate to scanner (DEFAULT CONFIG) after splash
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) context.go('/scanner');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: AppTheme.lightBackground,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 12,
                        intensity: 0.8,
                        shape: NeumorphicShape.convex,
                        boxShape: const NeumorphicBoxShape.circle(),
                        color: AppTheme.lightBackground,
                      ),
                      child: const SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 50,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Receipt Logger',
                      style: AppTheme.displayLarge.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan. Log. Track.',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

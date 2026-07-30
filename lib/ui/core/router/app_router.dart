import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/verification/views/verification_screen.dart';
import '../../features/history/views/history_screen.dart';
import '../../features/analytics/views/analytics_screen.dart';
import '../../features/paywall/views/paywall_screen.dart';
import '../../features/auth/views/auth_screen.dart';
import '../../features/ai_assistant/views/ai_assistant_screen.dart';
import '../../features/settings/views/settings_screen.dart';

Page<dynamic> _buildNeumorphicPage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const DashboardScreen()),
    ),
    GoRoute(
      path: '/verification',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const VerificationScreen()),
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const HistoryScreen()),
    ),
    GoRoute(
      path: '/analytics',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const AnalyticsScreen()),
    ),
    GoRoute(
      path: '/paywall',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const PaywallScreen()),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const AuthScreen()),
    ),
    GoRoute(
      path: '/ai-assistant',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const AiAssistantScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const SettingsScreen()),
    ),
  ],
);

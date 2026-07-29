import 'package:go_router/go_router.dart';

import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/verification/views/verification_screen.dart';
import '../../features/history/views/history_screen.dart';
import '../../features/analytics/views/analytics_screen.dart';
import '../../features/paywall/views/paywall_screen.dart';
import '../../features/auth/views/auth_screen.dart';
import '../../features/ai_assistant/views/ai_assistant_screen.dart';
import '../../features/settings/views/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/verification',
      builder: (context, state) => const VerificationScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/ai-assistant',
      builder: (context, state) => const AiAssistantScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

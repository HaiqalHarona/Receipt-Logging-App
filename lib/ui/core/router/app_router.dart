import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'main_tab_shell.dart';
import '../../features/verification/views/verification_screen.dart';
import '../../features/receipt_detail/views/receipt_detail_screen.dart';
import '../../features/analytics/views/analytics_screen.dart';
import '../../features/paywall/views/paywall_screen.dart';
import '../../features/auth/views/auth_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/signup_screen.dart';
import '../../features/auth/views/forgot_password_screen.dart';
import '../../features/settings/views/customization_screen.dart';
import '../../features/settings/views/db_viewer_screen.dart';
import '../../features/scanner/views/scanner_screen.dart';

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
    ShellRoute(
      builder: (context, state, child) => MainTabShell(
        currentPath: state.matchedLocation,
      ),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(child: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => const NoTransitionPage(child: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/ai-assistant',
          pageBuilder: (context, state) => const NoTransitionPage(child: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SizedBox.shrink()),
        ),
      ],
    ),
    GoRoute(
      path: '/verification',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const VerificationScreen()),
    ),
    GoRoute(
      path: '/receipt-detail',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const ReceiptDetailScreen()),
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
      path: '/login',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const LoginScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const SignUpScreen()),
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const ForgotPasswordScreen()),
    ),
    GoRoute(
      path: '/customization',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const CustomizationScreen()),
    ),
    GoRoute(
      path: '/settings/db-viewer',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const DbViewerScreen()),
    ),
    GoRoute(
      path: '/scanner',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const ScannerScreen()),
    ),
  ],
);

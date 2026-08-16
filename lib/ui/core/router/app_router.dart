import 'package:flutter/material.dart';
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
import '../../features/auth/views/otp_verification_screen.dart';
import '../../features/auth/views/reset_password_screen.dart';
import '../../features/settings/views/customization_screen.dart';
import '../../features/settings/views/db_viewer_screen.dart';
import '../../features/settings/views/user_settings_screen.dart';
import '../../features/scanner/views/scanner_screen.dart';

import '../../../cloud/services/auth_service.dart';
import '../../../../services/scan_batch_controller.dart';

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
        reverseCurve: Curves.easeInCubic,
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

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  refreshListenable: Listenable.merge([
    AuthService.instance,
    ScanBatchController.instance,
  ]),
  initialLocation: '/dashboard',
  redirect: (BuildContext context, GoRouterState state) {
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final isScanning = ScanBatchController.instance.isScanning;
    final path = state.matchedLocation;
    final isAuthRoute = path == '/login' || path == '/signup' || path == '/auth';

    if (isScanning && path == '/scanner') {
      return '/dashboard';
    }
    if (isLoggedIn && isAuthRoute) {
      return '/dashboard';
    }
    if (!isLoggedIn && path == '/user-settings') {
      return '/dashboard';
    }
    return null;
  },
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
      path: '/verify-otp',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final identifier = extra['identifier'] as String? ?? '';
        final devOtp = extra['dev_otp'] as String?;
        return _buildNeumorphicPage(
          state: state,
          child: OtpVerificationScreen(
            identifier: identifier,
            initialDevOtp: devOtp,
          ),
        );
      },
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final resetToken = extra['reset_token'] as String? ?? '';
        return _buildNeumorphicPage(
          state: state,
          child: ResetPasswordScreen(resetToken: resetToken),
        );
      },
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
      path: '/user-settings',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const UserSettingsScreen()),
    ),
    GoRoute(
      path: '/scanner',
      pageBuilder: (context, state) => _buildNeumorphicPage(state: state, child: const ScannerScreen()),
    ),
  ],
);

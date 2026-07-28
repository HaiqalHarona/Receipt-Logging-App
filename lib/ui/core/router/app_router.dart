import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:reciept_logging/ui/features/scanner/views/scanner_screen.dart';
import 'package:reciept_logging/ui/features/receipt_detail/views/receipt_detail_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/settings_screen.dart';
import 'package:reciept_logging/ui/features/splash/views/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'receipt/:id',
            name: 'receipt-detail',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ReceiptDetailScreen(receiptId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => const SplashScreen(),
  );
});

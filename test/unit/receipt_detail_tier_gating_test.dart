// File: test/unit/receipt_detail_tier_gating_test.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/currency_service.dart';
import 'package:reciept_logging/ui/features/receipt_detail/views/receipt_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleReceiptWithItems = Receipt(
    id: 'detail-test-001',
    merchant: 'Battercatch Seafood',
    date: '2026-10-01',
    amount: 98.20,
    currency: 'SGD',
    category: 'Dining',
    lineItems: [
      LineItem(
        description: 'Fish & Chips',
        quantity: 2,
        unitPrice: 40.0,
        totalPrice: 80.0,
      ),
      LineItem(
        description: 'Iced Lemon Tea',
        quantity: 2,
        unitPrice: 5.0,
        totalPrice: 10.0,
      ),
    ],
  );

  const sampleReceiptEmptyItems = Receipt(
    id: 'detail-test-002',
    merchant: 'Battercatch Seafood',
    date: '2026-10-01',
    amount: 98.20,
    currency: 'SGD',
    category: 'Dining',
    lineItems: [],
  );

  Widget createTestApp(Receipt receipt) {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => const ReceiptDetailScreen(),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) =>
              const Scaffold(body: Text('Paywall Screen Target')),
        ),
      ],
      initialExtra: receipt,
    );

    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => NeumorphicTheme(
        theme: const NeumorphicThemeData(
          baseColor: Color(0xFF2D3436),
          accentColor: Color(0xFF6C5CE7),
          lightSource: LightSource.topLeft,
          depth: 4,
          intensity: 0.7,
        ),
        child: child ?? const SizedBox(),
      ),
    );
  }

  setUp(() {
    CurrencyService.instance.setCurrency('USD');
  });

  group('ReceiptDetailScreen Tier Gating Tests', () {
    testWidgets('Free tier displays locked placeholder, thumbnail, and upgrade CTA chip navigates to /paywall', (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'free',
          scan: QuotaMetricDto(used: 1, limit: 10, remaining: 9, isExhausted: false),
          chat: QuotaMetricDto(used: 100, limit: 10000, remaining: 9900, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(createTestApp(sampleReceiptEmptyItems));
      await tester.pumpAndSettle();

      // Should show the locked icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Should show the upgrade CTA chip with text "Upgrade to Premium"
      expect(find.text('Upgrade to Premium'), findsOneWidget);

      // Should NOT show "No line items recorded."
      expect(find.text('No line items recorded.'), findsNothing);

      // Tapping Upgrade to Premium should navigate to /paywall
      await tester.tap(find.text('Upgrade to Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Paywall Screen Target'), findsOneWidget);
    });

    testWidgets('Premium tier with empty items displays "No line items recorded."', (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 1, limit: 50, remaining: 49, isExhausted: false),
          chat: QuotaMetricDto(used: 100, limit: 50000, remaining: 49900, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(createTestApp(sampleReceiptEmptyItems));
      await tester.pumpAndSettle();

      // Should NOT show the locked icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

      // Should show "No line items recorded."
      expect(find.text('No line items recorded.'), findsOneWidget);
    });

    testWidgets('Premium tier with items displays converted prices table', (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 1, limit: 50, remaining: 49, isExhausted: false),
          chat: QuotaMetricDto(used: 100, limit: 50000, remaining: 49900, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(createTestApp(sampleReceiptWithItems));
      await tester.pumpAndSettle();

      // Should NOT show the locked icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

      // Should show item descriptions
      expect(find.text('Fish & Chips'), findsOneWidget);
      expect(find.text('Iced Lemon Tea'), findsOneWidget);
    });
  });
}

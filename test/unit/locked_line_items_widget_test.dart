// File: test/unit/locked_line_items_widget_test.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/ui/core/widgets/receipt_image_thumbnail.dart';
import 'package:reciept_logging/ui/features/edit_receipt/views/edit_receipt_screen.dart';
import 'package:reciept_logging/ui/features/verification/views/widgets/verification_card_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testReceipt = Receipt(
    id: 'test-receipt-uuid-001',
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

  group('QuotaService isPremium Getter Tests', () {
    test('isPremium is false when tier is free', () {
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
      expect(QuotaService.instance.tier, equals('free'));
      expect(QuotaService.instance.isPremium, isFalse);
    });

    test('isPremium is true when tier is premium', () {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 5, limit: 50, remaining: 45, isExhausted: false),
          chat: QuotaMetricDto(used: 500, limit: 50000, remaining: 49500, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );
      expect(QuotaService.instance.tier, equals('premium'));
      expect(QuotaService.instance.isPremium, isTrue);
    });

    test('isPremium is true when tier is dev', () {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'dev',
          scan: QuotaMetricDto(used: 0, limit: -1, remaining: -1, isExhausted: false),
          chat: QuotaMetricDto(used: 0, limit: -1, remaining: -1, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );
      expect(QuotaService.instance.tier, equals('dev'));
      expect(QuotaService.instance.isPremium, isTrue);
    });
  });

  group('VerificationCardWidget Tier Gating Tests', () {
    Widget buildTestWidget({required bool isPremium}) {
      final router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/test',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: VerificationCardWidget(
                  receipt: testReceipt,
                  onChanged: (_) {},
                  textPrimary: Colors.black87,
                  textSecondary: Colors.black54,
                  accent: const Color(0xFF6C5CE7),
                  isPremium: isPremium,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/paywall',
            builder: (context, state) =>
                const Scaffold(body: Text('Paywall Screen Target')),
          ),
        ],
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

    testWidgets('VerificationCardWidget renders ReceiptImageThumbnail at the top', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPremium: false));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptImageThumbnail), findsOneWidget);
    });

    testWidgets('Free tier (isPremium=false) renders locked placeholder with lock icon and CTA chip navigates to /paywall', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPremium: false));
      await tester.pumpAndSettle();

      // Should show the Line Items section header
      expect(find.text('Line Items'), findsOneWidget);

      // Should show the lock icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Should show the upgrade CTA chip
      expect(find.text('Upgrade to Premium'), findsOneWidget);

      // Should NOT show the Add Line Item button
      expect(find.text('Add Line Item'), findsNothing);

      // Core fields must still be present and editable
      expect(find.text('Battercatch Seafood'), findsOneWidget);

      // Tapping CTA chip should navigate to /paywall
      final ctaFinder = find.text('Upgrade to Premium');
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      expect(find.text('Paywall Screen Target'), findsOneWidget);
    });

    testWidgets('Premium tier (isPremium=true) renders full editable line items table', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPremium: true));
      await tester.pumpAndSettle();

      // Should show the Line Items section header
      expect(find.text('Line Items'), findsOneWidget);

      // Should NOT show the lock icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

      // Should NOT show the upgrade CTA chip
      expect(find.text('Upgrade to Premium'), findsNothing);

      // Should show the Add Line Item button
      expect(find.text('Add Line Item'), findsOneWidget);

      // Should show item descriptions in the table
      expect(find.text('Fish & Chips'), findsOneWidget);
      expect(find.text('Iced Lemon Tea'), findsOneWidget);
    });
  });

  group('EditReceiptScreen Tier Gating Tests', () {
    Widget buildEditScreenApp(Receipt receipt) {
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (context, state) => const EditReceiptScreen(),
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

    testWidgets('EditReceiptScreen with Free tier passes isPremium=false and renders locked items', (tester) async {
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

      await tester.pumpWidget(buildEditScreenApp(testReceipt));
      await tester.pumpAndSettle();

      // Free user on edit screen should see the locked placeholder and CTA chip
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.text('Add Line Item'), findsNothing);

      // Thumbnail is rendered
      expect(find.byType(ReceiptImageThumbnail), findsOneWidget);
    });

    testWidgets('EditReceiptScreen with Premium tier passes isPremium=true and renders editable items', (tester) async {
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

      await tester.pumpWidget(buildEditScreenApp(testReceipt));
      await tester.pumpAndSettle();

      // Premium user on edit screen should see full line items and Add Line Item button
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.text('Upgrade to Premium'), findsNothing);
      expect(find.text('Add Line Item'), findsOneWidget);
      expect(find.text('Fish & Chips'), findsOneWidget);

      // Thumbnail is rendered
      expect(find.byType(ReceiptImageThumbnail), findsOneWidget);
    });
  });
}

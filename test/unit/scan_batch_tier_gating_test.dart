// File: test/unit/scan_batch_tier_gating_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/services/scan_batch_controller.dart';
import 'package:reciept_logging/ui/core/widgets/scan_progress_snack_bar.dart';
import 'package:reciept_logging/ui/core/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createSnackBarTestHarness({
    required void Function(BuildContext context) onTrigger,
  }) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => onTrigger(context),
                child: const Text('Show SnackBar'),
              ),
            );
          },
        ),
      ),
    );
  }

  group('ScanProgressSnackBar Tier-Aware Rendering Tests', () {
    tearDown(() {
      ScanProgressSnackBar.dismiss();
    });

    testWidgets('Free tier displays sequential message and interactive minimalist badge',
        (tester) async {
      bool upgradeTapped = false;
      bool cancelTapped = false;

      await tester.pumpWidget(
        createSnackBarTestHarness(
          onTrigger: (context) {
            ScanProgressSnackBar.show(
              context: context,
              message: 'Scanning receipts (1/5)…',
              badgeText: 'Sequential',
              onCancel: () => cancelTapped = true,
              onUpgrade: () => upgradeTapped = true,
            );
          },
        ),
      );

      // Tap button to show SnackBar
      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sequential text is displayed
      expect(find.text('Scanning receipts (1/5)…'), findsOneWidget);

      // Verify minimalist badge is rendered without crowded speed text
      expect(find.text('Sequential'), findsOneWidget);
      expect(find.text('Upgrade for 4x speed'), findsNothing);

      // Tap the sequential badge
      await tester.tap(find.text('Sequential'));
      await tester.pump();
      expect(upgradeTapped, isTrue);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelTapped, isTrue);
    });

    testWidgets('Premium tier displays parallel message with minimalist badge and no upgrade CTA',
        (tester) async {
      await tester.pumpWidget(
        createSnackBarTestHarness(
          onTrigger: (context) {
            ScanProgressSnackBar.show(
              context: context,
              message: 'Scanning receipts (3/8)…',
              badgeText: 'Parallel',
              onCancel: () {},
            );
          },
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify parallel progressive text and badge are displayed
      expect(find.text('Scanning receipts (3/8)…'), findsOneWidget);
      expect(find.text('Parallel'), findsOneWidget);

      // Verify upgrade chip is NOT present
      expect(find.text('Upgrade for 4x speed'), findsNothing);
      expect(find.text('Sequential'), findsNothing);
    });

    testWidgets('Legacy format with bullet bolt gracefully parses into Sequential badge',
        (tester) async {
      bool upgradeTapped = false;

      await tester.pumpWidget(
        createSnackBarTestHarness(
          onTrigger: (context) {
            ScanProgressSnackBar.show(
              context: context,
              message:
                  'Scanning receipt 1 of 5 (Sequential) • ⚡ Upgrade for 4x speed',
              onCancel: () {},
              onUpgrade: () => upgradeTapped = true,
            );
          },
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sequential'), findsOneWidget);
      await tester.tap(find.text('Sequential'));
      await tester.pump();
      expect(upgradeTapped, isTrue);
    });
  });

  group('Batch Limit Intercept Sheet Tests', () {
    testWidgets('Free tier limit sheet renders upgrade, trim-to-5, and cancel actions',
        (tester) async {
      BatchLimitAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final action = await showModalBottomSheet<BatchLimitAction>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (ctx) => const BatchLimitSheetContent(
                        totalCount: 8,
                        isFreeTier: true,
                      ),
                    );
                    selectedAction = action;
                  },
                  child: const Text('Open Free Limit Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Free Limit Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Scan Limit (Free Tier)'), findsOneWidget);
      expect(find.text('5 receipts maximum on Free'), findsOneWidget);
      expect(find.text('Upgrade to Premium (8 receipts)'), findsOneWidget);
      expect(find.text('Scan First 5 Receipts for Free'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap 'Scan First 5 Receipts for Free'
      await tester.tap(find.text('Scan First 5 Receipts for Free'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(BatchLimitAction.trim));
    });

    testWidgets('Free tier limit sheet upgrade button triggers upgrade action',
        (tester) async {
      BatchLimitAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final action = await showModalBottomSheet<BatchLimitAction>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (ctx) => const BatchLimitSheetContent(
                        totalCount: 7,
                        isFreeTier: true,
                      ),
                    );
                    selectedAction = action;
                  },
                  child: const Text('Open Free Limit Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Free Limit Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upgrade to Premium (7 receipts)'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(BatchLimitAction.upgrade));
    });

    testWidgets('Premium limit sheet renders 10-receipt limit without paywall',
        (tester) async {
      BatchLimitAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final action = await showModalBottomSheet<BatchLimitAction>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (ctx) => const BatchLimitSheetContent(
                        totalCount: 14,
                        isFreeTier: false,
                      ),
                    );
                    selectedAction = action;
                  },
                  child: const Text('Open Premium Limit Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Premium Limit Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Scan Limit'), findsOneWidget);
      expect(find.text('10 receipts maximum per batch'), findsOneWidget);
      expect(find.text('Scan First 10 Receipts'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Verify no paywall CTA is rendered for Premium users
      expect(find.textContaining('Upgrade to Premium'), findsNothing);

      // Tap 'Scan First 10 Receipts'
      await tester.tap(find.text('Scan First 10 Receipts'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(BatchLimitAction.trim));
    });

    testWidgets('Premium limit sheet cancel button dismisses cleanly',
        (tester) async {
      BatchLimitAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final action = await showModalBottomSheet<BatchLimitAction>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (ctx) => const BatchLimitSheetContent(
                        totalCount: 12,
                        isFreeTier: false,
                      ),
                    );
                    selectedAction = action;
                  },
                  child: const Text('Open Premium Limit Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Premium Limit Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedAction, equals(BatchLimitAction.cancel));
    });
  });

  group('QuotaService Tier Checks for Batch Concurrency', () {
    test('QuotaService correctly reflects free vs premium tier', () {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'free',
          scan: QuotaMetricDto(used: 0, limit: 10, remaining: 10, isExhausted: false),
          chat: QuotaMetricDto(used: 0, limit: 10000, remaining: 10000, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );
      expect(QuotaService.instance.isPremium, isFalse);

      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 0, limit: 100, remaining: 100, isExhausted: false),
          chat: QuotaMetricDto(used: 0, limit: 100000, remaining: 100000, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );
      expect(QuotaService.instance.isPremium, isTrue);
    });
  });
}

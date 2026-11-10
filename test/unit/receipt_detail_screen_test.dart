// File: test/unit/receipt_detail_screen_test.dart

import 'dart:async';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/models/receipt_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/data/repositories/receipt_repository.dart';
import 'package:reciept_logging/domain/models/line_item.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/services/currency_service.dart';
import 'package:reciept_logging/ui/features/receipt_detail/views/receipt_detail_screen.dart';

class MockJitBackendApiClient extends BackendApiClient {
  ReceiptRecordDto? mockRecord;
  int fetchCallCount = 0;
  String? lastFetchedId;
  Completer<ReceiptRecordDto?>? completer;

  @override
  Future<ReceiptRecordDto?> fetchReceiptById(
    String receiptId, {
    String? username,
    String? userToken,
  }) async {
    fetchCallCount++;
    lastFetchedId = receiptId;
    if (completer != null) {
      return completer!.future;
    }
    return mockRecord;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiClient originalApiClient;
  late MockJitBackendApiClient mockClient;

  const sampleEmptyReceipt = Receipt(
    id: 'receipt-jit-101',
    merchant: 'Artisan Bistro',
    date: '2026-10-17',
    amount: 42.50,
    currency: 'USD',
    category: 'Dining',
    lineItems: [],
  );

  const samplePopulatedReceipt = Receipt(
    id: 'receipt-jit-102',
    merchant: 'Supermart',
    date: '2026-10-17',
    amount: 15.00,
    currency: 'USD',
    category: 'Groceries',
    lineItems: [
      LineItem(
        description: 'Milk 1 Gal',
        quantity: 1,
        unitPrice: 5.0,
        totalPrice: 5.0,
      ),
    ],
  );

  final mockCloudRecord = ReceiptRecordDto(
    id: 'receipt-jit-101',
    deviceId: 'test-device-uuid',
    createdAt: '2026-10-17T12:00:00Z',
    receipt: const ReceiptDto(
      merchantName: 'Artisan Bistro',
      totalAmount: 42.50,
      date: '2026-10-17',
      currency: 'USD',
      rawText: 'Artisan Bistro...',
      lineItems: [
        LineItemDto(
          description: 'Truffle Fries',
          quantity: 1,
          unitPrice: 12.50,
          totalPrice: 12.50,
        ),
        LineItemDto(
          description: 'Wagyu Burger',
          quantity: 1,
          unitPrice: 30.00,
          totalPrice: 30.00,
        ),
      ],
    ),
  );

  Widget createTestApp(Receipt receipt, {bool? paywallResult}) {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => const ReceiptDetailScreen(),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.pop(paywallResult ?? true),
                child: const Text('Simulate Paywall Upgrade'),
              ),
            ),
          ),
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
    originalApiClient = BackendApiClient.instance;
    mockClient = MockJitBackendApiClient();
    BackendApiClient.instance = mockClient;
    CurrencyService.instance.setCurrency('USD');
  });

  tearDown(() {
    BackendApiClient.instance = originalApiClient;
  });

  group('ReceiptDetailScreen JIT Hydration & Shimmer UI Tests', () {
    testWidgets(
        'On Premium tier with empty line items, displays shimmer skeleton during JIT fetch then hydrates rows',
        (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 1, limit: 50, remaining: 49, isExhausted: false),
          chat: QuotaMetricDto(used: 10, limit: 1000, remaining: 990, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      final completer = Completer<ReceiptRecordDto?>();
      mockClient.completer = completer;

      await tester.pumpWidget(createTestApp(sampleEmptyReceipt));
      await tester.pump(); // Initiate dependencies and trigger JIT fetch

      // 1. Shimmer skeleton should be visible during fetch
      expect(find.text('Unlocking itemized breakdown...'), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(mockClient.fetchCallCount, 1);
      expect(mockClient.lastFetchedId, 'receipt-jit-101');

      // 2. Complete fetch with mock line items
      completer.complete(mockCloudRecord);
      await tester.pumpAndSettle();

      // 3. Shimmer skeleton should be gone
      expect(find.text('Unlocking itemized breakdown...'), findsNothing);

      // 4. Converted item descriptions should now be displayed
      expect(find.text('Truffle Fries'), findsOneWidget);
      expect(find.text('Wagyu Burger'), findsOneWidget);

      // 5. Local repository should have the updated receipt
      final saved = ReceiptRepository.instance.receipts
          .firstWhere((r) => r.id == 'receipt-jit-101');
      expect(saved.lineItems.length, 2);
      expect(saved.lineItems.first.description, 'Truffle Fries');
    });

    testWidgets(
        'On Free tier, does NOT trigger JIT fetch and displays locked placeholder',
        (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'free',
          scan: QuotaMetricDto(used: 1, limit: 10, remaining: 9, isExhausted: false),
          chat: QuotaMetricDto(used: 5, limit: 500, remaining: 495, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(createTestApp(sampleEmptyReceipt));
      await tester.pumpAndSettle();

      // Free tier: locked placeholder, no JIT fetch
      expect(mockClient.fetchCallCount, 0);
      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.text('Unlocking itemized breakdown...'), findsNothing);
    });

    testWidgets(
        'On Premium tier with existing line items, does NOT trigger redundant JIT fetch',
        (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 1, limit: 50, remaining: 49, isExhausted: false),
          chat: QuotaMetricDto(used: 10, limit: 1000, remaining: 990, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(createTestApp(samplePopulatedReceipt));
      await tester.pumpAndSettle();

      // Line items already exist: no JIT fetch
      expect(mockClient.fetchCallCount, 0);
      expect(find.text('Milk 1 Gal'), findsOneWidget);
    });

    testWidgets(
        'Tapping Upgrade to Premium and completing paywall triggers JIT line items fetch',
        (tester) async {
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'free',
          scan: QuotaMetricDto(used: 1, limit: 10, remaining: 9, isExhausted: false),
          chat: QuotaMetricDto(used: 5, limit: 500, remaining: 495, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );
      mockClient.mockRecord = mockCloudRecord;

      await tester.pumpWidget(createTestApp(sampleEmptyReceipt, paywallResult: true));
      await tester.pumpAndSettle();

      expect(mockClient.fetchCallCount, 0);
      expect(find.text('Upgrade to Premium'), findsOneWidget);

      // Tap Upgrade CTA
      await tester.tap(find.text('Upgrade to Premium'));
      await tester.pumpAndSettle();

      // User is on simulated Paywall screen
      expect(find.text('Simulate Paywall Upgrade'), findsOneWidget);

      // Upgrade to Premium
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'premium',
          scan: QuotaMetricDto(used: 1, limit: 50, remaining: 49, isExhausted: false),
          chat: QuotaMetricDto(used: 10, limit: 1000, remaining: 990, isExhausted: false),
          resetAt: null,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      // Tap simulate upgrade button which pops back with true
      await tester.tap(find.text('Simulate Paywall Upgrade'));
      await tester.pumpAndSettle();

      // JIT fetch should have completed and rendered line items
      expect(mockClient.fetchCallCount, 1);
      expect(find.text('Truffle Fries'), findsOneWidget);
      expect(find.text('Wagyu Burger'), findsOneWidget);
    });
  });
}

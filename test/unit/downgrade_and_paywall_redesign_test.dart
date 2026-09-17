// File: test/unit/downgrade_and_paywall_redesign_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/models/subscription_models.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/subscription/views/premium_paywall_sheet.dart';
import 'package:reciept_logging/ui/features/subscription/widgets/downgrade_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: Scaffold(body: child),
    );
  }

  group('Redesigned DowngradeDay15Dialog Tests', () {
    testWidgets('renders all key components, stats, and dual interactive preview cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockStats = UserStatsDto(
        totalReceipts: 42,
        timeSavedSeconds: 150.0,
        timeSavedMinutes: 2.5,
        tier: 'free',
        isInTrial: false,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        const DowngradeDay15Dialog(stats: mockStats),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header and badge
      expect(find.text('TRIAL COMPLETED · EXCLUSIVE OFFER'), findsOneWidget);
      expect(find.text('Your Premium Trial Has Ended'), findsOneWidget);

      // Usage stats
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Receipts Saved'), findsOneWidget);
      expect(find.text('2.5m'), findsOneWidget);
      expect(find.text('Time Saved (AI)'), findsOneWidget);

      // 7-day urgency banner
      expect(find.text('Special 7-Day Discount'), findsOneWidget);
      expect(find.text('7 Days Left'), findsOneWidget);

      // Dual interactive preview cards
      expect(find.text('3 MONTHS FREE'), findsOneWidget);
      expect(find.text('Annual · Save 33%'), findsOneWidget);
      expect(find.text('1 MONTH FREE'), findsOneWidget);
      expect(find.text('Monthly Plan'), findsOneWidget);

      // Primary CTA and dismiss button
      expect(find.text('Claim 3 Months Free & Upgrade'), findsOneWidget);
      expect(find.text('Continue with Free Plan'), findsOneWidget);
    });
  });

  group('Redesigned PremiumPaywallSheet Tests', () {
    testWidgets('Annual plan is pre-selected by default with dominant BEST VALUE badge and dynamic CTA',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-paywall-1',
          username: 'PaywallUser',
          email: 'paywall@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        const PremiumPaywallSheet(isFullPage: true),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header
      expect(find.text('SancFund Premium'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);

      // Annual plan recommended badge
      expect(find.text('MOST POPULAR · BEST VALUE'), findsOneWidget);
      expect(find.text('\$3.99'), findsOneWidget);
      expect(find.text('\$5.99'), findsNWidgets(2)); // Monthly price + Annual strikethrough

      // Initial CTA button defaults to Annual
      expect(find.text('Upgrade to Annual (Save 33%)'), findsOneWidget);

      // Tapping Monthly card switches selection and dynamically updates CTA button
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Upgrade to Monthly'), findsOneWidget);
    });

    testWidgets('Opening paywall with initialPlan = monthly pre-selects Monthly plan',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-paywall-2',
          username: 'MonthlyUser',
          email: 'monthly@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        const PremiumPaywallSheet(
          isFullPage: true,
          initialPlan: PaywallPlanType.monthly,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dynamic CTA reflects initial Monthly selection
      expect(find.text('Upgrade to Monthly'), findsOneWidget);
    });
  });
}

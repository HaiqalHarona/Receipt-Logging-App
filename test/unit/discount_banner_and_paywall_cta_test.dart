// File: test/unit/discount_banner_and_paywall_cta_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/models/subscription_models.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/subscription/views/premium_paywall_sheet.dart';
import 'package:reciept_logging/ui/features/subscription/widgets/discount_offer_banner.dart';
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

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('DiscountOfferBanner Gating & Expiry Tests', () {
    testWidgets('does NOT render when user is logged out (guest mode)',
        (WidgetTester tester) async {
      configureViewport(tester);

      // By default AuthService has no session saved, so isLoggedIn is false
      const activeStatus = SubscriptionStatusDto(
        tier: 'free',
        isInTrial: false,
        isTrialExpired: true,
        isDiscountActive: true,
        discountDaysRemaining: 5,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        const DiscountOfferBanner(status: activeStatus),
      ));
      await tester.pump();

      expect(find.text('Special Discount'), findsNothing);
      expect(find.text('Claim'), findsNothing);
    });

    testWidgets('renders when user is logged in and discount is active with trial history',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-discount-1',
          username: 'DiscountUser',
          email: 'discount@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      final activeStatus = SubscriptionStatusDto(
        tier: 'free',
        isInTrial: false,
        trialStartAt: DateTime(2026, 8, 1),
        isTrialExpired: true,
        isDiscountActive: true,
        discountDaysRemaining: 5,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        DiscountOfferBanner(status: activeStatus),
      ));
      await tester.pump();

      expect(find.text('Special Discount'), findsOneWidget);
      expect(find.text('5 days left'), findsOneWidget);
      expect(find.text('Claim'), findsOneWidget);

      // Verify vector fire icon is used instead of emoji 🔥
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.text('🔥'), findsNothing);
    });

    testWidgets('does NOT render when user account never had a trial (trialStartAt is null)',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-discount-no-trial',
          username: 'NoTrialUser',
          email: 'notrial@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      const ineligibleStatus = SubscriptionStatusDto(
        tier: 'free',
        isInTrial: false,
        trialStartAt: null, // Never went through 14-day trial
        isTrialExpired: false,
        isDiscountActive: true,
        discountDaysRemaining: 5,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        const DiscountOfferBanner(status: ineligibleStatus),
      ));
      await tester.pump();

      expect(find.text('Special Discount'), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    testWidgets('does NOT render when user is already premium tier',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-discount-premium',
          username: 'PremiumUser',
          email: 'premium@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'premium',
        ),
        userToken: 'mock-token',
      );

      final premiumStatus = SubscriptionStatusDto(
        tier: 'premium',
        isInTrial: false,
        trialStartAt: DateTime(2026, 8, 1),
        isTrialExpired: true,
        isDiscountActive: true,
        discountDaysRemaining: 5,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        DiscountOfferBanner(status: premiumStatus),
      ));
      await tester.pump();

      expect(find.text('Special Discount'), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    testWidgets('does NOT render when discount is expired or inactive',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-discount-2',
          username: 'ExpiredDiscountUser',
          email: 'expired@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      // Case 1: isDiscountActive is false
      final inactiveStatus = SubscriptionStatusDto(
        tier: 'free',
        isInTrial: false,
        trialStartAt: DateTime(2026, 8, 1),
        isTrialExpired: true,
        isDiscountActive: false,
        discountDaysRemaining: 0,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        DiscountOfferBanner(status: inactiveStatus),
      ));
      await tester.pump();
      expect(find.text('Special Discount'), findsNothing);

      // Case 2: discountDaysRemaining is 0
      final expiredDaysStatus = SubscriptionStatusDto(
        tier: 'free',
        isInTrial: false,
        trialStartAt: DateTime(2026, 8, 1),
        isTrialExpired: true,
        isDiscountActive: true,
        discountDaysRemaining: 0,
        adScansToday: 0,
        adScansRemaining: 5,
      );

      await tester.pumpWidget(buildTestableWidget(
        DiscountOfferBanner(status: expiredDaysStatus),
      ));
      await tester.pump();
      expect(find.text('Special Discount'), findsNothing);
    });
  });

  group('Downgrade Dialog Action & Return Tests', () {
    const mockStats = UserStatsDto(
      totalReceipts: 15,
      timeSavedSeconds: 120.0,
      timeSavedMinutes: 2.0,
      tier: 'free',
      isInTrial: false,
      adScansToday: 0,
      adScansRemaining: 5,
    );

    testWidgets('tapping Claim 3 Months Free & Upgrade pops PaywallPlanType.annual',
        (WidgetTester tester) async {
      configureViewport(tester);
      PaywallPlanType? result;

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<PaywallPlanType>(
                context: context,
                builder: (ctx) => const DowngradeDay15Dialog(stats: mockStats),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Claim 3 Months Free & Upgrade'), findsOneWidget);
      await tester.tap(find.text('Claim 3 Months Free & Upgrade'));
      await tester.pumpAndSettle();

      expect(result, PaywallPlanType.annual);
    });

    testWidgets('tapping Monthly preview card pops PaywallPlanType.monthly',
        (WidgetTester tester) async {
      configureViewport(tester);
      PaywallPlanType? result;

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<PaywallPlanType>(
                context: context,
                builder: (ctx) => const DowngradeDay15Dialog(stats: mockStats),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Plan'), findsOneWidget);
      await tester.tap(find.text('Monthly Plan'));
      await tester.pumpAndSettle();

      expect(result, PaywallPlanType.monthly);
    });

    testWidgets('tapping Continue with Free Plan pops null',
        (WidgetTester tester) async {
      configureViewport(tester);
      PaywallPlanType? result = PaywallPlanType.annual;

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<PaywallPlanType>(
                context: context,
                builder: (ctx) => const DowngradeDay15Dialog(stats: mockStats),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Free Plan'), findsOneWidget);
      await tester.tap(find.text('Continue with Free Plan'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('DowngradeReminderDialog pops true on Claim Discount and false on Dismiss',
        (WidgetTester tester) async {
      configureViewport(tester);
      bool? reminderResult;

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              reminderResult = await showDialog<bool>(
                context: context,
                builder: (ctx) => const DowngradeReminderDialog(
                  dayNumber: 1,
                  daysRemaining: 6,
                ),
              );
            },
            child: const Text('Open Reminder'),
          ),
        ),
      ));

      // Test Claim Discount
      await tester.tap(find.text('Open Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claim Discount'));
      await tester.pumpAndSettle();
      expect(reminderResult, isTrue);

      // Test Dismiss
      await tester.tap(find.text('Open Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(reminderResult, isFalse);
    });
  });

  group('PremiumPaywallSheet Purchase Tap & SnackBar Feedback Tests', () {
    testWidgets('tapping purchase CTA triggers clear feedback when package is null',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-paywall-feedback',
          username: 'FeedbackUser',
          email: 'feedback@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        const PremiumPaywallSheet(isFullPage: false),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the CTA button
      final ctaFinder = find.text('Upgrade to Annual (Save 33%)');
      expect(ctaFinder, findsOneWidget);

      // Tap CTA button
      await tester.tap(ctaFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar should be rendered on the sheet
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('ineligible accounts without trial history do NOT see offer banners or free month badges',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-paywall-no-trial',
          username: 'NoTrialPaywallUser',
          email: 'notrialpaywall@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        const PremiumPaywallSheet(isFullPage: false),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Standard non-offer badges must be visible
      expect(find.text('SAVE 33%'), findsOneWidget);
      expect(find.text('FLEXIBLE'), findsOneWidget);

      // Offer badges and discount copies must NOT be displayed
      expect(find.text('3 MONTHS FREE'), findsNothing);
      expect(find.text('1 MONTH FREE'), findsNothing);
      expect(find.text('FIRST MONTH OFF'), findsNothing);
      expect(find.text('Special Downgrade Offer'), findsNothing);
    });

    testWidgets('showPremiumPaywallSheet configures fixed height to 5/6 of screen',
        (WidgetTester tester) async {
      configureViewport(tester);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-paywall-height',
          username: 'HeightUser',
          email: 'height@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPremiumPaywallSheet(context),
            child: const Text('Launch Paywall'),
          ),
        ),
      ));

      await tester.tap(find.text('Launch Paywall'));
      await tester.pumpAndSettle();

      // Find the SizedBox that constrains the modal sheet
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final matchingBox = sizedBoxes.firstWhere(
        (box) => box.height != null && (box.height! - (1400 * (5 / 6))).abs() < 1.0,
      );
      expect(matchingBox.height, closeTo(1400 * (5 / 6), 0.1));
    });
  });
}

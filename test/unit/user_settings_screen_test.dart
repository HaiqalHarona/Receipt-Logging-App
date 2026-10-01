// File: test/unit/user_settings_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';
import 'package:intl/intl.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/services/sync_coordinator.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  group('UserSettingsScreen Widget Tests', () {
    testWidgets(
        'UserSettingsScreen renders header, profile info, and Log Out button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed mock profile in AuthService
      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-mock-12345',
          username: 'TestUserQA',
          email: 'testuser@example.com',
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Account & Profile'), findsOneWidget);
      expect(find.text('TestUserQA'), findsOneWidget);
      expect(find.text('UID: usr-mock-12345'), findsOneWidget);
      expect(find.text('CONTACT & SECURITY'), findsOneWidget);
      expect(find.text('View & Edit'), findsOneWidget);
      expect(find.text('Change contact, configure security, and more'),
          findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsWidgets);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byTooltip('Edit Contact & Security'), findsNothing);
      expect(find.text('EMAIL ADDRESS'), findsNothing);
      expect(find.text('MOBILE NUMBER'), findsNothing);
      expect(find.text('ACCOUNT PASSWORD'), findsNothing);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets(
        'Tapping View & Edit navigates to /user-settings/contact-security',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-mock-12345',
          username: 'TestUserQA',
          email: 'testuser@example.com',
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-xyz',
      );

      bool navigatedToContactSecurity = false;
      final testRouter = GoRouter(
        initialLocation: '/user-settings',
        routes: [
          GoRoute(
            path: '/user-settings',
            builder: (context, state) => const UserSettingsScreen(),
          ),
          GoRoute(
            path: '/user-settings/contact-security',
            builder: (context, state) {
              navigatedToContactSecurity = true;
              return const SizedBox.shrink();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
          builder: (context, child) => NeumorphicTheme(
            themeMode: ThemeMode.dark,
            darkTheme: AppTheme.darkNeumorphicTheme,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final viewEditFinder = find.text('View & Edit');
      expect(viewEditFinder, findsOneWidget);

      await tester.tap(viewEditFinder);
      await tester.pumpAndSettle();

      expect(navigatedToContactSecurity, isTrue);
    });

    testWidgets(
        'AuthService caching returns cached profile without network call',
        (WidgetTester tester) async {
      const mockUser = UserRecordDto(
        id: 'usr-cache-99',
        username: 'CachedUser',
        email: 'cached@example.com',
        countryCode: '+60',
        mobileNumber: '123456789',
        createdAt: '2026-08-10T12:00:00Z',
      );

      await AuthService.instance.saveSession(mockUser);
      final profile = await AuthService.instance.getOrFetchProfile();

      expect(profile, isNotNull);
      expect(profile!.id, equals('usr-cache-99'));
      expect(profile.username, equals('CachedUser'));
      expect(profile.email, equals('cached@example.com'));
      expect(profile.countryCode, equals('+60'));
    });

    testWidgets(
        'Plan & Usage section renders with FREE tier and Upgrade button; tapping opens Upgrade bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-free-1',
          username: 'FreeTierUser',
          email: 'free@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PLAN & USAGE section header
      expect(find.text('PLAN & USAGE'), findsOneWidget);
      expect(find.text('FREE'), findsAtLeastNWidgets(1));

      // Enticing Upgrade button is present on Free tier
      expect(find.text('Upgrade'), findsOneWidget);

      // Tap Upgrade button
      await tester.tap(find.text('Upgrade'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Upgrade bottom sheet is opened with Annual plan pre-selected by default
      expect(find.text('Premium'), findsAtLeastNWidgets(1));
      expect(find.text('Loading prices…'), findsOneWidget);
      expect(find.text('50 Daily Receipt Scans'), findsOneWidget);
      expect(find.text('50,000 AI Chat Tokens'), findsOneWidget);
      expect(find.text('Priority Vision OCR Processing'), findsOneWidget);
      expect(find.text('4x Faster Bulk Scanning'), findsOneWidget);
      expect(find.text(r'$3.99'), findsNothing);
    });

    testWidgets(
        'Dev tier renders DEV badge without icon, hides Upgrade button, and sets quota bars to 100% full',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-dev-1',
          username: 'DevTierUser',
          email: 'dev@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'dev',
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DEV'), findsAtLeastNWidgets(1));
      // Upgrade button should be hidden for Dev tier
      expect(find.text('Upgrade'), findsNothing);

      // Verify LinearProgressIndicators are rendered at 1.0
      final indicators = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicators.length, equals(2));
      for (final indicator in indicators) {
        expect(indicator.value, equals(1.0));
      }
    });

    testWidgets(
        'When offline, Log Out button displays disabled state and tooltip',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SyncCoordinator.instance.setOnlineForTesting(false);
      addTearDown(() => SyncCoordinator.instance.setOnlineForTesting(true));

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-offline-1',
          username: 'OfflineUser',
          email: 'offline@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: null,
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Log Out button renders with offline tooltip
      expect(
          find.byTooltip(
              'Log out requires an internet connection to safeguard your local data'),
          findsOneWidget);
    });

    testWidgets(
        'UserSettingsScreen with active trial renders trial end status line and simulate trial expiry button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now().toUtc();
      await AuthService.instance.saveSession(
        UserRecordDto(
          id: 'usr-trial-1',
          username: 'TrialUser',
          email: 'trial@example.com',
          createdAt: now.toIso8601String(),
          tier: 'premium',
          preferences: {
            'is_in_trial': true,
            'trial_start_at': now.toIso8601String(),
          },
        ),
        userToken: 'mock-trial-token',
      );

      await tester.pumpWidget(buildTestableWidget(
        const UserSettingsScreen(highlightPlan: true),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // PLAN & USAGE header is present
      expect(find.text('PLAN & USAGE'), findsOneWidget);

      // Status line with 14-Day Trial Active is visible
      expect(
        find.textContaining('14-Day Trial Active · Ends on'),
        findsOneWidget,
      );

      // Simulate 14-Day Trial Expiration button is rendered
      expect(
        find.text('Simulate 14-Day Trial Expiration'),
        findsOneWidget,
      );

      // Advance timer past 4-second highlight animation
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
        'Plan & Usage section renders Manage button for paid PREMIUM tier; no Upgrade button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-premium-paid-1',
          username: 'PremiumPaidUser',
          email: 'premium-paid@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'premium',
        ),
        userToken: 'mock-token-premium-paid',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PLAN & USAGE section
      expect(find.text('PLAN & USAGE'), findsOneWidget);
      expect(find.text('PREMIUM'), findsAtLeastNWidgets(1));

      // Manage button present, Upgrade button absent
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);

      // Tap Manage button to open bottom sheet
      await tester.tap(find.text('Manage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Manage Your Subscription'), findsOneWidget);
      expect(find.text('Manage on Google Play'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets(
        'Plan & Usage displays countdown timer below tier name with tap tooltip showing local reset time and removes Resets 00:00 UTC',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixedResetUtc = DateTime.utc(2026, 9, 25, 0, 0);
      final expectedLocalTime =
          DateFormat('HH:mm').format(fixedResetUtc.toLocal());

      QuotaService.instance.setStatusForTesting(
        QuotaStatusDto(
          tier: 'free',
          scan: const QuotaMetricDto(
              used: 2, limit: 10, remaining: 8, isExhausted: false),
          chat: const QuotaMetricDto(
              used: 1000, limit: 10000, remaining: 9000, isExhausted: false),
          resetAt: fixedResetUtc,
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-free-1',
          username: 'FreeUser',
          email: 'free@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token-free',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PLAN & USAGE section rendered
      expect(find.text('PLAN & USAGE'), findsOneWidget);

      // 'Resets 00:00 UTC' text is no longer rendered
      expect(find.text('Resets 00:00 UTC'), findsNothing);

      // Tooltip is present with expected local reset time
      final tooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message == 'Quota resets at $expectedLocalTime',
      );
      expect(tooltipFinder, findsOneWidget);

      // Verify the Tooltip wraps the countdown timer text
      expect(
        find.descendant(
          of: tooltipFinder,
          matching: find.text(QuotaService.instance.liveResetCountdown),
        ),
        findsOneWidget,
      );
    });
  });
}

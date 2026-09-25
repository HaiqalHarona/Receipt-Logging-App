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
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('MOBILE NUMBER'), findsOneWidget);
      expect(find.text('+ Add'), findsOneWidget);
      expect(find.text('ACCOUNT PASSWORD'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets(
        'Mobile Number + Add button is disabled with Coming Soon tooltip and does not open modal',
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

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final tooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message?.contains('Coming Soon') ?? false),
      );
      expect(tooltipFinder, findsOneWidget);

      // Tapping + Add does not open bottom sheet
      await tester.tap(find.text('+ Add'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Update Mobile Number'), findsNothing);
      expect(find.text('Save Mobile'), findsNothing);
    });

    testWidgets(
        'Tapping Reset Password opens the bottom sheet with all required inputs',
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

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Reset button
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Reset Account Password'), findsOneWidget);
      expect(find.text('CURRENT PASSWORD'), findsOneWidget);
      expect(find.text('NEW PASSWORD'), findsOneWidget);
      expect(find.text('CONFIRM NEW PASSWORD'), findsOneWidget);
      expect(find.text('8+ chars'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets(
        'When 7-day cooldown is active, Reset button is indented/disabled and shows tooltip',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Password changed 2 days ago -> 5 days remaining
      final twoDaysAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String();

      await AuthService.instance.saveSession(
        UserRecordDto(
          id: 'usr-cooldown-123',
          username: 'CooldownUser',
          email: 'cooldown@example.com',
          preferences: {'password_changed_at': twoDaysAgo},
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tooltip should be present with "Change allowed in 5 days"
      final tooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message?.contains('Change allowed in 5 days') ?? false),
      );
      expect(tooltipFinder, findsOneWidget);

      // Tapping the row during cooldown should do nothing (no bottom sheet opened)
      await tester.tap(find.text('ACCOUNT PASSWORD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Reset Account Password'), findsNothing);
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
      expect(profile.mobileNumber, equals('123456789'));
    });

    testWidgets(
        'Unverified email displays Verify button, and tapping it opens verification sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-unverified-1',
          username: 'UnverifiedUser',
          email: 'unverified@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: null,
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify button should be visible
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);

      // Tap Verify button
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Modal bottom sheet should be open
      expect(find.text('Verify Email Address'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('Verified email displays Verified badge and no Verify button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-verified-1',
          username: 'VerifiedUser',
          email: 'verified@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-20T10:00:00Z',
        ),
        userToken: 'mock-token-xyz',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // "Verified" badge should be visible, "Verify" button should not be present
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
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
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Loading prices…'), findsOneWidget);
      expect(find.text('50 Daily Receipt Scans'), findsOneWidget);
      expect(find.text('50,000 AI Chat Tokens'), findsOneWidget);
      expect(find.text('Priority Vision OCR Processing'), findsOneWidget);
      expect(find.text('Instant Multi-Device Cloud Sync'), findsOneWidget);
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
        'When offline, Verify, Reset, and Log Out buttons display disabled states and tooltips',
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

      // Verify button renders with offline tooltip
      expect(
          find.byTooltip('Email verification requires an internet connection'),
          findsOneWidget);

      // Password Reset button renders with offline tooltip
      expect(find.byTooltip('Password reset requires an internet connection'),
          findsOneWidget);

      // Log Out button renders with offline tooltip
      expect(
          find.byTooltip(
              'Log out requires an internet connection to safeguard your local data'),
          findsOneWidget);

      // Tapping Verify button does not open bottom sheet
      await tester.tap(find.text('Verify'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Verify Email Address'), findsNothing);

      // Tapping Reset button does not open bottom sheet
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Change Account Password'), findsNothing);
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

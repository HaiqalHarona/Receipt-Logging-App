// File: test/unit/contact_security_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/settings/views/contact_security_screen.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
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

  group('ContactSecurityScreen Widget Tests', () {
    testWidgets(
        'Renders top bar, header, and all 4 rows in single Neumorphic card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-1',
          username: 'TestUserCS',
          email: 'user@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header and Back button
      expect(find.text('Contact & Security'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Section header
      expect(find.text('CREDENTIALS & AUTHENTICATION'), findsOneWidget);

      // Row 1: Email Address
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.byTooltip('Edit Email Address'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Row 2: Mobile Number
      expect(find.text('MOBILE NUMBER'), findsOneWidget);
      expect(find.text('Not configured'), findsOneWidget);
      expect(find.text('+ Add'), findsOneWidget);

      // Row 3: Account Password
      expect(find.text('ACCOUNT PASSWORD'), findsOneWidget);
      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Row 4: Two-Factor Authentication
      expect(find.text('TWO-FACTOR AUTHENTICATION (2FA)'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets(
        'Unverified email renders Verify button; tapping it opens verification sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-unverified',
          username: 'UnverifiedCS',
          email: 'unverified@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: null,
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify button should be visible, check icon should not be
      expect(find.text('Verify'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Tap Verify button
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Modal bottom sheet should be open
      expect(find.text('Verify Email Address'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets(
        'Tapping edit email pencil icon opens Edit Email modal bottom sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-edit-email',
          username: 'EditEmailUser',
          email: 'original@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final editEmailFinder = find.byTooltip('Edit Email Address');
      expect(editEmailFinder, findsOneWidget);

      await tester.tap(editEmailFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Change Email Address'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets(
        '2FA toggle is disabled with tooltip when email is unverified',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-no-2fa',
          username: 'No2FAUser',
          email: 'no2fa@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: null,
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tooltip should be present with requirement message
      final tooltipFinder = find.byTooltip('Email verification required to enable 2FA');
      expect(tooltipFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets(
        '2FA toggle is interactive and displays snackbar when email is verified',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-verified-2fa',
          username: 'Verified2FAUser',
          email: 'verified2fa@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 2FA requirement tooltip should not be present
      expect(find.byTooltip('Email verification required to enable 2FA'), findsNothing);

      // Tap Switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
      expect(find.text('Two-factor authentication enabled.'), findsOneWidget);
    });

    testWidgets(
        'Mobile button is disabled with Coming Soon tooltip for both empty and configured mobile numbers',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Case 1: No mobile configured -> '+ Add'
      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-mobile-1',
          username: 'MobileUser1',
          email: 'mob1@example.com',
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('+ Add'), findsOneWidget);
      expect(find.byTooltip('Coming Soon'), findsOneWidget);

      // Case 2: Mobile configured -> 'Edit'
      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-mobile-2',
          username: 'MobileUser2',
          email: 'mob2@example.com',
          countryCode: '+60',
          mobileNumber: '123456789',
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(ContactSecurityScreen(key: UniqueKey())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('+60 123456789'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byTooltip('Coming Soon'), findsOneWidget);
    });

    testWidgets(
        'Tapping Reset Password opens password reset sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-reset',
          username: 'ResetUser',
          email: 'reset@example.com',
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
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
        'When 7-day cooldown is active, Reset button is disabled with tooltip',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final twoDaysAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2))
          .toIso8601String();

      await AuthService.instance.saveSession(
        UserRecordDto(
          id: 'usr-cooldown-cs',
          username: 'CooldownCSUser',
          email: 'cooldowncs@example.com',
          preferences: {'password_changed_at': twoDaysAgo},
          createdAt: '2026-08-10T12:00:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final tooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message?.contains('Password was recently changed. Change allowed in 5 days') ?? false),
      );
      expect(tooltipFinder, findsOneWidget);

      await tester.tap(tooltipFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Reset Account Password'), findsNothing);
    });

    testWidgets(
        'When offline, Verify and Reset buttons display disabled tooltips',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SyncCoordinator.instance.setOnlineForTesting(false);
      addTearDown(() => SyncCoordinator.instance.setOnlineForTesting(true));

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-offline',
          username: 'OfflineCSUser',
          email: 'offlinecs@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: null,
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify button renders with offline tooltip
      expect(
          find.byTooltip('Email verification requires an internet connection'),
          findsOneWidget);

      // Password Reset button renders with offline tooltip
      expect(
          find.byTooltip('Password reset requires an internet connection'),
          findsOneWidget);

      // Tapping Verify button does not open sheet
      await tester.tap(find.text('Verify'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Verify Email Address'), findsNothing);

      // Tapping Reset button does not open sheet
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reset Account Password'), findsNothing);
    });
  });
}

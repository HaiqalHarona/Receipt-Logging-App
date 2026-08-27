// File: test/unit/user_settings_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
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
            widget is Tooltip && (widget.message?.contains('Coming Soon') ?? false),
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
      final twoDaysAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String();

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
        (widget) => widget is Tooltip && (widget.message?.contains('Change allowed in 5 days') ?? false),
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

    testWidgets(
        'Verified email displays Verified badge and no Verify button',
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
  });
}



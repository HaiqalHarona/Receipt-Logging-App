// File: test/unit/contact_security_screen_test.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/settings/views/contact_security_screen.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/services/local_image_cache_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/services/sync_coordinator.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/cloud/api/backend_api_client.dart';

class Mock2faBackendApiClient extends BackendApiClient {
  bool request2faActionOtpCalled = false;
  String? lastRequestedAction;
  bool enable2faCalled = false;
  bool deleteUserProfileCalled = false;
  String? lastActionOtp;

  @override
  Future<({bool success, int cooldownSeconds})> request2faActionOtp({
    String action = 'security_action',
    String? username,
    String? userToken,
  }) async {
    request2faActionOtpCalled = true;
    lastRequestedAction = action;
    return (success: true, cooldownSeconds: 60);
  }

  @override
  Future<bool> deleteUserProfile({
    String? username,
    String? userToken,
    String? twoFactorOtp,
  }) async {
    deleteUserProfileCalled = true;
    lastActionOtp = twoFactorOtp;
    return true;
  }

  @override
  Future<UserRecordDto> enable2fa({required String otp, String? username, String? userToken}) async {
    enable2faCalled = true;
    return const UserRecordDto(
      id: 'usr-cs-verified-2fa',
      username: 'Verified2FAUser',
      email: 'verified2fa@example.com',
      is2faEnabled: true,
      createdAt: '2026-08-10T12:00:00Z',
      emailVerifiedAt: '2026-08-10T12:30:00Z',
    );
  }

  bool mockIs2faEnabled = true;

  @override
  Future<UserRecordDto> fetchUserProfile({String? username, String? userToken}) async {
    return UserRecordDto(
      id: 'usr-cs-${username ?? 'user'}',
      username: username ?? 'Verified2FAUser',
      email: '${username ?? 'user'}@example.com',
      is2faEnabled: mockIs2faEnabled,
      createdAt: '2026-08-10T12:00:00Z',
      emailVerifiedAt: '2026-08-10T12:30:00Z',
    );
  }

  @override
  Future<({bool success, String? passwordChangedAt})> changePassword({
    required String oldPassword,
    required String newPassword,
    String? username,
    String? userToken,
    String? twoFactorOtp,
  }) async {
    return (
      success: true,
      passwordChangedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<({bool success, int cooldownSeconds})> initiateVerification({
    required String type,
    required String identifier,
    String? username,
    String? userToken,
  }) async {
    return (success: true, cooldownSeconds: 60);
  }

  @override
  Future<UserRecordDto> completeVerification({
    required String type,
    required String identifier,
    required String otp,
    String? username,
    String? userToken,
  }) async {
    return const UserRecordDto(
      id: 'usr-cs-unverified',
      username: 'UnverifiedCS',
      email: 'unverified@example.com',
      createdAt: '2026-08-10T12:00:00Z',
      emailVerifiedAt: '2026-10-03T12:00:00Z',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LocalImageCacheService.instance.setCacheBaseDirForTesting(
        Directory.systemTemp.createTempSync('cache_test_'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.createTempSync('cache_test_').path;
      },
    );
  });

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  Widget buildTestableWidgetWithRouter(Widget child,
      {void Function()? onAuthNavigated}) {
    final router = GoRouter(
      initialLocation: '/security',
      routes: [
        GoRoute(
          path: '/security',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) {
            onAuthNavigated?.call();
            return const Scaffold(body: Text('AuthScreen'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, c) => NeumorphicTheme(
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.darkNeumorphicTheme,
        child: c ?? const SizedBox.shrink(),
      ),
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
      expect(find.text('Verified'), findsOneWidget);

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
      expect(find.byType(NeumorphicToggleSwitch), findsOneWidget);
    });

    testWidgets(
        'Unverified email renders Verify button; tapping it opens verification sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalClient = BackendApiClient.instance;
      final mockClient = Mock2faBackendApiClient();
      BackendApiClient.instance = mockClient;
      addTearDown(() => BackendApiClient.instance = originalClient);

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

      // TwoFactorOtpSheet modal bottom sheet should be open
      expect(find.text('Verify Email Address'), findsOneWidget);
      expect(find.text('Enter the 6-digit verification code sent to your email to verify your address.'), findsOneWidget);
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

      final switchWidget = tester.widget<NeumorphicToggleSwitch>(find.byType(NeumorphicToggleSwitch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets(
        '2FA toggle triggers OTP bottom sheet and enables 2FA upon verification',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalClient = BackendApiClient.instance;
      final mockClient = Mock2faBackendApiClient();
      BackendApiClient.instance = mockClient;
      addTearDown(() => BackendApiClient.instance = originalClient);

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

      // Tap NeumorphicToggleSwitch
      await tester.tap(find.byType(NeumorphicToggleSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockClient.request2faActionOtpCalled, isTrue);
      expect(find.text('Enable Two-Factor Authentication'), findsOneWidget);

      // Enter OTP into 2FA sheet
      await tester.enterText(find.byKey(const Key('2fa_otp_input')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(mockClient.enable2faCalled, isTrue);

      final switchWidget = tester.widget<NeumorphicToggleSwitch>(find.byType(NeumorphicToggleSwitch));
      expect(switchWidget.value, isTrue);
      expect(find.text('Two-factor authentication enabled successfully.'), findsOneWidget);
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

    testWidgets(
        'Changing password with 2FA active preserves email verified status and 2FA switch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalClient = BackendApiClient.instance;
      final mockClient = Mock2faBackendApiClient();
      BackendApiClient.instance = mockClient;
      addTearDown(() => BackendApiClient.instance = originalClient);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-verified-2fa',
          username: 'Verified2FAUser',
          email: 'verified2fa@example.com',
          is2faEnabled: true,
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially verified and 2FA switch is on
      expect(find.text('Verified'), findsOneWidget);
      final switchInitial =
          tester.widget<NeumorphicToggleSwitch>(find.byKey(const Key('2fa_switch')));
      expect(switchInitial.value, isTrue);

      // Tap Reset password
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enter old and new passwords
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'oldpassword123');
      await tester.enterText(textFields.at(1), 'NewPassword123!');
      await tester.enterText(textFields.at(2), 'NewPassword123!');
      await tester.pump();

      // Tap Update Password
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 2FA OTP prompt appears because 2FA is active
      expect(find.text('Confirm Password Change'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('2fa_otp_input')), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify email remains verified and 2FA toggle remains enabled and on!
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
      final switchFinal =
          tester.widget<NeumorphicToggleSwitch>(find.byKey(const Key('2fa_switch')));
      expect(switchFinal.value, isTrue);
      expect(find.byKey(const Key('2fa_switch_disabled')), findsNothing);
    });

    testWidgets(
        'Danger Zone section renders DANGER ZONE header and DELETE ACCOUNT card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-danger-zone',
          username: 'DangerZoneUser',
          email: 'dangerzone@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.text('DELETE ACCOUNT'), findsOneWidget);
      expect(find.text('Permanently delete your account and all data'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
        'Tapping Delete button opens delete account sheet with warning, input, and disabled confirm button until DELETE is typed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-delete-sheet',
          username: 'DeleteSheetUser',
          email: 'deletesheet@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Delete in Danger Zone card
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal content
      expect(find.text('Delete Account Permanently?'), findsOneWidget);
      expect(
          find.text(
              'All your receipts, AI conversations, and profile data will be permanently and irrecoverably destroyed. This action cannot be undone.'),
          findsOneWidget);
      expect(find.text('TYPE "Delete Account Forever" TO CONFIRM'), findsOneWidget);

      final confirmBtnFinder = find.byKey(const Key('confirm_delete_account_button'));
      expect(confirmBtnFinder, findsOneWidget);

      // Typing wrong casing keeps button inactive
      final inputFinder = find.byKey(const Key('delete_account_confirm_input'));
      await tester.enterText(inputFinder, 'delete');
      await tester.pump();

      // Enter "Delete Account Forever" verbatim
      await tester.enterText(inputFinder, 'Delete Account Forever');
      await tester.pump();

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account Permanently?'), findsNothing);
    });

    testWidgets(
        'Deleting account without 2FA calls deleteUserProfile, wipes session, and navigates to /auth',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalClient = BackendApiClient.instance;
      final mockClient = Mock2faBackendApiClient();
      mockClient.mockIs2faEnabled = false;
      BackendApiClient.instance = mockClient;
      addTearDown(() => BackendApiClient.instance = originalClient);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-delete-no2fa',
          username: 'DeleteNo2faUser',
          email: 'deleteno2fa@example.com',
          is2faEnabled: false,
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      bool authNavigated = false;
      await tester.pumpWidget(buildTestableWidgetWithRouter(
        const ContactSecurityScreen(),
        onAuthNavigated: () => authNavigated = true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AuthService.instance.isLoggedIn, isTrue);

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Type "Delete Account Forever"
      await tester.enterText(
          find.byKey(const Key('delete_account_confirm_input')), 'Delete Account Forever');
      await tester.pump();

      // Tap Confirm Delete
      await tester.tap(find.byKey(const Key('confirm_delete_account_button')));
      await tester.pump();
      for (int i = 0; i < 25 && !authNavigated; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockClient.deleteUserProfileCalled, isTrue);
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(authNavigated, isTrue);
      expect(find.text('AuthScreen'), findsOneWidget);
    });

    testWidgets(
        'Deleting account with 2FA calls request2faActionOtp, prompts TwoFactorOtpSheet, and deletes account',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalClient = BackendApiClient.instance;
      final mockClient = Mock2faBackendApiClient();
      mockClient.mockIs2faEnabled = true;
      BackendApiClient.instance = mockClient;
      addTearDown(() => BackendApiClient.instance = originalClient);

      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-cs-delete-2fa',
          username: 'Delete2faUser',
          email: 'delete2fa@example.com',
          is2faEnabled: true,
          createdAt: '2026-08-10T12:00:00Z',
          emailVerifiedAt: '2026-08-10T12:30:00Z',
        ),
        userToken: 'mock-token-cs',
      );

      bool authNavigated = false;
      await tester.pumpWidget(buildTestableWidgetWithRouter(
        const ContactSecurityScreen(),
        onAuthNavigated: () => authNavigated = true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AuthService.instance.isLoggedIn, isTrue);

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Type "Delete Account Forever"
      await tester.enterText(
          find.byKey(const Key('delete_account_confirm_input')), 'Delete Account Forever');
      await tester.pump();

      // Tap Confirm Delete
      await tester.tap(find.byKey(const Key('confirm_delete_account_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify OTP requested for delete_account action
      expect(mockClient.request2faActionOtpCalled, isTrue);
      expect(mockClient.lastRequestedAction, 'delete_account');

      // TwoFactorOtpSheet appears
      expect(find.text('Confirm Account Deletion'), findsOneWidget);

      // Enter OTP
      await tester.enterText(find.byKey(const Key('2fa_otp_input')), '889900');
      await tester.pump();
      for (int i = 0; i < 25 && !authNavigated; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockClient.deleteUserProfileCalled, isTrue);
      expect(mockClient.lastActionOtp, '889900');
      expect(AuthService.instance.isLoggedIn, isFalse);
      expect(authNavigated, isTrue);
      expect(find.text('AuthScreen'), findsOneWidget);
    });
  });
}

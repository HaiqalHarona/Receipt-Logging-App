// File: test/unit/user_settings_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  group('UserSettingsScreen Widget Tests', () {
    testWidgets('UserSettingsScreen renders header, profile info, and Log Out button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed mock profile in AuthService
      await AuthService.instance.saveSession(const UserRecordDto(
        id: 'usr-mock-12345',
        username: 'TestUserQA',
        email: 'testuser@example.com',
        createdAt: '2026-08-10T12:00:00Z',
      ));

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('User Settings'), findsOneWidget);
      expect(find.text('TestUserQA'), findsOneWidget);
      expect(find.text('User ID: usr-mock-12345'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('MOBILE'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('AuthService caching returns cached profile without network call', (WidgetTester tester) async {
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
  });
}

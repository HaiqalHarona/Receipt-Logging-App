// File: test/unit/signup_and_forgot_password_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/features/auth/views/signup_screen.dart';
import 'package:reciept_logging/ui/features/auth/views/forgot_password_screen.dart';
import 'package:reciept_logging/ui/features/auth/views/otp_verification_screen.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/cloud/api/api_config.dart';

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

  group('SignUpScreen Widget Tests', () {
    testWidgets(
        'SignUpScreen renders fields, Sign Up CTA, and Log In bottom link',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const SignUpScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create ${ApiConfig.appName} Account'), findsOneWidget);
      expect(find.widgetWithText(NeumorphicButtonWidget, 'Create Account'), findsOneWidget);
      expect(find.text('ACCOUNT INFORMATION'), findsOneWidget);
      expect(find.text('SECURITY CREDENTIALS'), findsOneWidget);
      expect(find.text('1. Account'), findsOneWidget);
      expect(find.text('2. Security'), findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(
          plainTexts.any((t) => t.contains('Already have an account? Log In')),
          isTrue);
    });

    testWidgets(
        'Submitting SignUpScreen with empty username shows error SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const SignUpScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NeumorphicButtonWidget, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Username is required.'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen Widget Tests', () {
    testWidgets(
        'ForgotPasswordScreen renders Email or Mobile input, Send Reset Code CTA, and Log In link',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('EMAIL OR MOBILE NUMBER'), findsOneWidget);
      expect(find.text('Send Reset Code'), findsOneWidget);

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final plainTexts = richTextFinder
          .evaluate()
          .map((e) => (e.widget as RichText).text.toPlainText());
      expect(
          plainTexts.any((t) => t.contains('Remember your password? Log In')),
          isTrue);
    });

    testWidgets(
        'Submitting ForgotPasswordScreen with empty input shows error inline',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester
          .tap(find.widgetWithText(NeumorphicButtonWidget, 'Send Reset Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email or mobile number.'),
          findsOneWidget);
    });
  });

  group('OtpVerificationScreen & ResetPasswordScreen Widget Tests', () {
    testWidgets(
        'OtpVerificationScreen renders 6-digit code input and verify CTA',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const OtpVerificationScreen(
        identifier: 'user@example.com',
        initialDevOtp: '849201',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Enter Reset Code'), findsOneWidget);
      expect(find.text('6-DIGIT CODE'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
    });
  });
}

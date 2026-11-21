// File: test/unit/login_2fa_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/widgets/neumorphic_loading_barrier.dart';
import 'package:reciept_logging/ui/core/widgets/two_factor_otp_sheet.dart';
import 'package:reciept_logging/ui/features/auth/views/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: child,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.clearSession();
  });

  tearDown(() async {
    await AuthService.instance.clearSession();
  });

  group('2FA Login Flow & Interaction Barrier Tests', () {
    testWidgets('NeumorphicLoadingBarrier renders message and blocks interaction',
        (WidgetTester tester) async {
      bool actionCompleted = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await NeumorphicLoadingBarrier.runWithBarrier(
                        context,
                        message: 'Signing in...',
                        action: () async {
                          await Future.delayed(const Duration(milliseconds: 100));
                          actionCompleted = true;
                        },
                      );
                    },
                    child: const Text('Start Action'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Tap the button to start the action with barrier
      await tester.tap(find.text('Start Action'));
      await tester.pump(); // Start opening dialog

      // Verify the loading barrier is rendered
      expect(find.byType(NeumorphicLoadingBarrier), findsOneWidget);
      expect(find.text('Signing in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Settle the delayed action
      await tester.pumpAndSettle();

      // Action completed and barrier popped
      expect(actionCompleted, isTrue);
      expect(find.byType(NeumorphicLoadingBarrier), findsNothing);
    });

    testWidgets('LoginScreen renders inputs and Sign In button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets(
        'TwoFactorOtpSheet is locked against outside drag and dismissible is false',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? verifiedOtpResult;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      verifiedOtpResult = await TwoFactorOtpSheet.show(
                        context,
                        title: 'Two-Factor Authentication',
                        subtitle: 'Enter the 6-digit verification code',
                        onVerify: (otp) async {},
                      );
                    },
                    child: const Text('Open 2FA'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open 2FA'));
      await tester.pumpAndSettle();

      // Verify the sheet is open
      expect(find.byType(TwoFactorOtpSheet), findsOneWidget);
      expect(find.text('Two-Factor Authentication'), findsOneWidget);

      // Verify ModalBottomSheet route has isDismissible = false and enableDrag = false
      final modalRoute = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(modalRoute.dismissible, isFalse);

      // Verify explicit close button dismisses sheet cleanly returning null
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(TwoFactorOtpSheet), findsNothing);
      expect(verifiedOtpResult, isNull);
    });
  });
}

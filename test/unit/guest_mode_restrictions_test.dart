// File: test/unit/guest_mode_restrictions_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/models/quota_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/cloud/services/quota_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/widgets/account_required_dialog.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';
import 'package:reciept_logging/ui/features/subscription/views/premium_paywall_sheet.dart';
import 'package:reciept_logging/ui/features/subscription/widgets/ad_scan_reward_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.clearSession();
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

  group('AccountRequiredDialog Widget Tests', () {
    testWidgets('renders dialog with title, message, and CTA buttons',
        (WidgetTester tester) async {
      configureViewport(tester);

      await tester.pumpWidget(buildTestableWidget(
        const AccountRequiredDialog(
          title: 'Account Required',
          message: 'Please sign in to proceed.',
        ),
      ));
      await tester.pump();

      expect(find.text('Account Required'), findsOneWidget);
      expect(find.text('Please sign in to proceed.'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('tapping Maybe Later pops the dialog',
        (WidgetTester tester) async {
      configureViewport(tester);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AccountRequiredDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Tap open
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountRequiredDialog), findsOneWidget);

      // Tap Maybe Later
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountRequiredDialog), findsNothing);
    });
  });

  group('showPremiumPaywallSheet Guest Mode Guard Tests', () {
    testWidgets('in guest mode (logged out), shows AccountRequiredDialog and returns false',
        (WidgetTester tester) async {
      configureViewport(tester);

      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showPremiumPaywallSheet(context);
              },
              child: const Text('Open Paywall'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Tap button while logged out
      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Verifies AccountRequiredDialog is shown instead of PremiumPaywallSheet
      expect(find.byType(AccountRequiredDialog), findsOneWidget);
      expect(find.text('Sign In for Premium'), findsOneWidget);
      expect(find.byType(PremiumPaywallSheet), findsNothing);
      expect(result, isFalse);
    });
  });

  group('AdScanPromptDialog Guest Mode Tests', () {
    testWidgets('renders daily limit reached and sign in CTA when logged out',
        (WidgetTester tester) async {
      configureViewport(tester);

      await tester.pumpWidget(buildTestableWidget(
        const AdScanPromptDialog(),
      ));
      await tester.pump();

      expect(find.text('Daily Scan Limit Reached'), findsOneWidget);
      expect(
        find.text(
          'Guest mode includes 5 scans per day. Sign in or register to unlock bonus ad scans, cloud sync, and unlimited premium plans.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign In / Register'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
      expect(find.text('Watch Ad for +1 Scan'), findsNothing);
    });
  });

  group('ScannerQuotaExhaustedBanner Guest Mode Tests', () {
    testWidgets('shows Sign In CTA when logged out and quota is exhausted',
        (WidgetTester tester) async {
      configureViewport(tester);

      // Simulate quota exhausted
      QuotaService.instance.setStatusForTesting(
        const QuotaStatusDto(
          success: true,
          tier: 'free',
          scan: QuotaMetricDto(
            used: 5,
            limit: 5,
            remaining: 0,
            isExhausted: true,
          ),
          chat: QuotaMetricDto(
            used: 100,
            limit: 1000,
            remaining: 900,
            isExhausted: false,
          ),
          secondsToReset: 3600,
          resetCountdown: '1h 0m',
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        const ScannerQuotaExhaustedBanner(),
      ));
      await tester.pump();

      expect(find.text('Daily Scan Limit Reached (5/5)'), findsOneWidget);
      expect(find.text('Sign in to unlock more scans & sync'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('+1 Scan'), findsNothing);
    });
  });

  group('UserSettingsScreen Defense-in-depth Tests', () {
    testWidgets('renders SizedBox.shrink when logged out',
        (WidgetTester tester) async {
      configureViewport(tester);

      await tester.pumpWidget(buildTestableWidget(
        const UserSettingsScreen(),
      ));
      await tester.pump();

      // Since user is logged out, the build method immediately returns SizedBox.shrink()
      expect(find.text('Account Details'), findsNothing);
      expect(find.text('Active Member'), findsNothing);
      expect(find.text('Account Settings'), findsNothing);
    });
  });
}

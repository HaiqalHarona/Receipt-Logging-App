// File: test/unit/trial_ineligible_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/ui/core/widgets/trial_ineligible_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({VoidCallback? onPaywallPushed}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TrialIneligibleDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) {
            onPaywallPushed?.call();
            return const Scaffold(body: Text('Paywall Screen'));
          },
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  testWidgets('TrialIneligibleDialog renders title, message, and both action buttons',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Trial Ineligible'), findsOneWidget);

    // Verify Message
    expect(
      find.text(
        'This device or email address has already been used for a free trial or active subscription. Your account has been set to the Free plan.',
      ),
      findsOneWidget,
    );

    // Verify Action buttons
    expect(find.text('View Plans'), findsOneWidget);
    expect(find.text('Continue on Free Tier'), findsOneWidget);
  });

  testWidgets('Tapping Continue on Free Tier dismisses the dialog', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Trial Ineligible'), findsOneWidget);

    await tester.tap(find.text('Continue on Free Tier'));
    await tester.pumpAndSettle();

    expect(find.text('Trial Ineligible'), findsNothing);
  });

  testWidgets('Tapping View Plans navigates to /paywall and closes dialog', (tester) async {
    bool paywallNavigated = false;
    await tester.pumpWidget(buildTestApp(onPaywallPushed: () {
      paywallNavigated = true;
    }));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Plans'));
    await tester.pumpAndSettle();

    expect(find.text('Trial Ineligible'), findsNothing);
    expect(paywallNavigated, isTrue);
    expect(find.text('Paywall Screen'), findsOneWidget);
  });
}

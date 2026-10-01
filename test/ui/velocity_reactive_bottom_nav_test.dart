// File: test/ui/velocity_reactive_bottom_nav_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reciept_logging/ui/core/router/main_tab_shell.dart';
import 'package:reciept_logging/ui/core/widgets/bottom_nav_bar.dart';
import 'package:reciept_logging/services/tutorial_service.dart';

void main() {
  // Helper to build the app shell for testing
  Widget buildTestableShell({required String path}) {
    return MaterialApp(
      home: MainTabShell(currentPath: path),
      // Provide a minimal GoRouter to satisfy context.go calls in NavItem
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }

  testWidgets('Downward scroll hides bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pumpAndSettle();

    // Find a scrollable widget inside the dashboard (assume at least one)
    final scrollable = find.byType(Scrollable).first;
    expect(scrollable, findsOneWidget);

    // Perform a drag downwards (content moves up, simulating downward scroll) with medium speed
    await tester.drag(scrollable, const Offset(0, -8));
    await tester.pumpAndSettle();

    // Verify that the bottom navigation bar is hidden (opacity 0)
    final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
    expect(animatedOpacity.opacity, equals(0.0));
  });

  testWidgets('Upward scroll reveals bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    // Hide first with medium speed drag
    await tester.drag(scrollable, const Offset(0, -8));
    await tester.pumpAndSettle();
    // Now drag upward to reveal with medium speed
    await tester.drag(scrollable, const Offset(0, 8));
    await tester.pumpAndSettle();

    // Verify that the bottom navigation bar is visible (opacity 1)
    final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
    expect(animatedOpacity.opacity, equals(1.0));
  });

  testWidgets('Tutorial step 1 keeps nav bar visible during scroll', (WidgetTester tester) async {
    // Ensure tutorial step 1 is active
    TutorialService.instance.setStep(1);
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    // Attempt a medium‑speed downward drag
    await tester.drag(scrollable, const Offset(0, -8));
    await tester.pumpAndSettle();

    // Nav bar should remain visible
    final navBar = find.byType(AppBottomNavBar);
    expect(navBar, findsOneWidget);
    final navBarOffset = tester.getTopLeft(navBar);
    final screenSize = tester.binding.window.physicalSize / tester.binding.window.devicePixelRatio;
    expect(navBarOffset.dy, lessThan(screenSize.height));
  });

  testWidgets('Tab switch resets navigation bar visibility', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    // Hide nav bar with medium speed drag
    await tester.drag(scrollable, const Offset(0, -8));
    await tester.pumpAndSettle();

    // Switch tab by tapping the History nav item
    final historyNavItem = find.text('History');
    expect(historyNavItem, findsOneWidget);
    await tester.tap(historyNavItem);
    await tester.pumpAndSettle();

    final navBar = find.byType(AppBottomNavBar);
    expect(navBar, findsOneWidget);
    final navBarOffset = tester.getTopLeft(navBar);
    final screenSize = tester.binding.window.physicalSize / tester.binding.window.devicePixelRatio;
    // After tab change, nav bar should be visible again
    expect(navBarOffset.dy, lessThan(screenSize.height));
  });
}

// File: test/ui/velocity_reactive_bottom_nav_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter/material.dart';
import 'package:reciept_logging/ui/core/router/main_tab_shell.dart';
import 'package:reciept_logging/ui/core/widgets/bottom_nav_bar.dart';
import 'package:reciept_logging/services/tutorial_service.dart';

void main() {
  setUp(() async {
    await TutorialService.instance.dismissTutorial();
  });

  tearDown(() async {
    await TutorialService.instance.resetForTesting();
  });

  Widget buildTestableShell({required String path}) {
    return MaterialApp(
      home: MainTabShell(currentPath: path),
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }

  AnimatedOpacity getNavBarOpacity(WidgetTester tester) {
    return tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(AppBottomNavBar),
        matching: find.byType(AnimatedOpacity),
      ),
    );
  }

  AnimatedSlide getNavBarSlide(WidgetTester tester) {
    return tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.byType(AppBottomNavBar),
        matching: find.byType(AnimatedSlide),
      ),
    );
  }

  void dispatchScrollDelta(WidgetTester tester, double delta, {double pixels = 100.0}) {
    final element = tester.element(find.byType(Scrollable).first);
    ScrollUpdateNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: pixels,
        viewportDimension: 600.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      ),
      context: element,
      scrollDelta: delta,
    ).dispatch(element);
  }

  testWidgets('Slow and fast scrolls do not hide bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Slow speed (delta = 2.0 < 4.0)
    dispatchScrollDelta(tester, 2.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));

    // Fast speed (delta = 20.0 > 12.0)
    dispatchScrollDelta(tester, 20.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));
  });

  testWidgets('Downward medium-speed scroll hides bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Medium speed (delta = 8.0, 4.0 <= delta <= 12.0)
    dispatchScrollDelta(tester, 8.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify hidden
    expect(getNavBarOpacity(tester).opacity, equals(0.0));
    expect(getNavBarSlide(tester).offset, equals(const Offset(0, 1.45)));
  });

  testWidgets('Upward medium-speed scroll reveals bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Hide first with downward medium speed
    dispatchScrollDelta(tester, 8.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(getNavBarOpacity(tester).opacity, equals(0.0));

    // Reveal with upward medium speed (delta = -8.0)
    dispatchScrollDelta(tester, -8.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify visible
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));
  });

  testWidgets('Reaching top of page (pixels <= 0) auto-reveals bottom navigation bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Hide first
    dispatchScrollDelta(tester, 8.0, pixels: 100.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(getNavBarOpacity(tester).opacity, equals(0.0));

    // Reach top (pixels = 0.0)
    dispatchScrollDelta(tester, 0.0, pixels: 0.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify auto-revealed
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));
  });

  testWidgets('Tutorial step 1 keeps nav bar visible during scroll', (WidgetTester tester) async {
    TutorialService.instance.setStep(1);
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Medium-speed downward scroll attempted during tutorial step 1
    dispatchScrollDelta(tester, 8.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Nav bar must remain visible
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));
  });

  testWidgets('Tab switch resets navigation bar visibility', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableShell(path: '/dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Hide nav bar with medium-speed scroll
    dispatchScrollDelta(tester, 8.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(getNavBarOpacity(tester).opacity, equals(0.0));

    // Switch tab by rebuilding with different path (simulating route change)
    await tester.pumpWidget(buildTestableShell(path: '/history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Nav bar should be visible again
    expect(getNavBarOpacity(tester).opacity, equals(1.0));
    expect(getNavBarSlide(tester).offset, equals(Offset.zero));
  });
}

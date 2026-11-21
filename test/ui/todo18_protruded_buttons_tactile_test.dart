// File: test/ui/todo18_protruded_buttons_tactile_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        hapticCalls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    hapticCalls.clear();
  });

  Widget wrapWithTheme(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.light,
      theme: const NeumorphicThemeData(
        baseColor: Color(0xFFF4F6F9),
        lightSource: LightSource.topLeft,
        depth: 4.0,
      ),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('TODO-18: NeumorphicTactileButton Tests', () {
    testWidgets('triggers synchronous zero-latency haptic on touch down (T=0ms)',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(wrapWithTheme(
        NeumorphicTactileButton(
          depth: 4.0,
          pressedDepth: 0.0,
          onPressed: () => pressed = true,
          child: const Text('Tactile Test'),
        ),
      ));

      expect(hapticCalls, isEmpty);
      expect(pressed, isFalse);

      // Perform touch down gesture without releasing
      final gesture = await tester.startGesture(tester.getCenter(find.text('Tactile Test')));
      await tester.pump();

      // Haptic must trigger IMMEDIATELY on touch down (0ms latency)
      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.lightImpact'));
      expect(pressed, isFalse);

      // Verify planar flatten: Neumorphic depth is 0.0 and AnimatedScale is 0.98
      final neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));

      final animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, equals(0.98));

      // Release finger
      await gesture.up();
      // Pump past 75ms dwell time + animation duration
      await tester.pump(const Duration(milliseconds: 150));

      expect(pressed, isTrue);

      // After release, depth springs back to rest depth 4.0 and scale to 1.0
      final releasedNeumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(releasedNeumorphic.style?.depth, equals(4.0));

      final releasedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(releasedScale.scale, equals(1.0));
    });

    testWidgets('respects 75ms minimum dwell time for ultra-fast taps',
        (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(wrapWithTheme(
        NeumorphicTactileButton(
          depth: 4.0,
          onPressed: () => pressed = true,
          child: const Text('Dwell Test'),
        ),
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Dwell Test')));
      await tester.pump(const Duration(milliseconds: 20)); // touch down for only 20ms
      await gesture.up(); // released early at 20ms

      // At 30ms elapsed, dwell protection (75ms minimum) must keep it pressed
      await tester.pump(const Duration(milliseconds: 10));
      final pressedNeumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(pressedNeumorphic.style?.depth, equals(0.0));

      // After advancing 100ms total, dwell completes and callback fires
      await tester.pump(const Duration(milliseconds: 100));
      expect(pressed, isTrue);

      final releasedNeumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(releasedNeumorphic.style?.depth, equals(4.0));
    });

    testWidgets('disabled button does not trigger haptics or compress',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const NeumorphicTactileButton(
          depth: 4.0,
          onPressed: null,
          child: Text('Disabled Test'),
        ),
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Disabled Test')));
      await tester.pump();

      expect(hapticCalls, isEmpty);

      final neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      // Disabled button is flat (depth 0.0) and unpressable (scale 1.0)
      expect(neumorphic.style?.depth, equals(0.0));

      final animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, equals(1.0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(hapticCalls, isEmpty);
    });
  });

  group('TODO-18: NeumorphicCircularButton & NeumorphicButtonWidget Tests', () {
    testWidgets('NeumorphicCircularButton compresses to 0.96 scale with haptic',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        NeumorphicCircularButton(
          icon: Icons.add,
          onTap: () => tapped = true,
        ),
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
      await tester.pump();

      expect(hapticCalls, hasLength(1));
      expect(hapticCalls.first.arguments, equals('HapticFeedbackType.lightImpact'));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, equals(0.96)); // Circular buttons micro-compress to 0.96

      final neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tapped, isTrue);
    });

    testWidgets('NeumorphicButtonWidget compresses to 0.98 scale and flattens to 0.0',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        NeumorphicButtonWidget(
          onPressed: () => tapped = true,
          child: const Text('Submit CTA'),
        ),
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Submit CTA')));
      await tester.pump();

      expect(hapticCalls, hasLength(1));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, equals(0.98));

      final neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tapped, isTrue);
    });
  });

  group('TODO-18: NeumorphicPressableRow Tests', () {
    testWidgets('NeumorphicPressableRow debosses to -1.5 on press down and flush on release',
        (WidgetTester tester) async {
      bool rowTapped = false;
      await tester.pumpWidget(wrapWithTheme(
        NeumorphicPressableRow(
          onTap: () => rowTapped = true,
          child: const Text('Settings Item'),
        ),
      ));

      // At rest: depth is 0.0 (flush)
      var neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Settings Item')));
      await tester.pump();

      // Immediate haptics at T=0
      expect(hapticCalls, hasLength(1));

      // On press down: deboss depth -1.5, scale 0.99
      neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(-1.5));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, equals(0.99));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(rowTapped, isTrue);

      // Rebounds back flush (depth: 0.0, scale: 1.0)
      neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));
    });
  });

  group('TODO-18: NeumorphicFilterChip Tests', () {
    testWidgets('NeumorphicFilterChip flattens to 0.0 on press down, then latches to -2.5',
        (WidgetTester tester) async {
      bool isSelected = false;
      await tester.pumpWidget(wrapWithTheme(
        StatefulBuilder(
          builder: (context, setState) {
            return NeumorphicFilterChip(
              isSelected: isSelected,
              label: 'Filter 1W',
              onSelected: (val) => setState(() => isSelected = val),
            );
          },
        ),
      ));

      // At rest (unselected): depth is restDepth 3.0
      var neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(3.0));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Filter 1W')));
      await tester.pump();

      // Immediate haptics
      expect(hapticCalls, hasLength(1));

      // On press down: flattens to 0.0, scale 0.97
      neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(0.0));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, equals(0.97));

      // On release: latches into selected depth -2.5
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));

      expect(isSelected, isTrue);
      neumorphic = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neumorphic.style?.depth, equals(-2.5));
    });
  });
}

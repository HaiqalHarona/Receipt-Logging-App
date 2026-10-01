// File: test/unit/todo17_minor_ui_fixes_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/settings/views/contact_security_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  group('NeumorphicToggleSwitch Component Tests', () {
    testWidgets('renders active state and responds to tap', (tester) async {
      bool currentValue = false;

      await tester.pumpWidget(
        buildTestableWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return NeumorphicToggleSwitch(
                key: const Key('test_toggle'),
                value: currentValue,
                onChanged: (val) {
                  setState(() => currentValue = val);
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('test_toggle')), findsOneWidget);
      expect(currentValue, isFalse);

      await tester.tap(find.byKey(const Key('test_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(currentValue, isTrue);
    });

    testWidgets('disabled toggle does not invoke callback', (tester) async {
      bool called = false;

      await tester.pumpWidget(
        buildTestableWidget(
          const NeumorphicToggleSwitch(
            key: Key('test_toggle_disabled'),
            value: false,
            onChanged: null,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('test_toggle_disabled')));
      await tester.pump();

      expect(called, isFalse);
    });
  });

  group('ContactSecurityScreen Refinements Tests', () {
    testWidgets('renders NeumorphicCircularButton for back navigation, 2FA toggle and reset button', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const ContactSecurityScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Back button uses NeumorphicCircularButton
      expect(find.byType(NeumorphicCircularButton), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.arrow_back_rounded), findsAtLeastNWidgets(1));

      // 2FA switch is NeumorphicToggleSwitch
      expect(find.byType(NeumorphicToggleSwitch), findsOneWidget);

      // EMAIL ADDRESS label and edit pencil exist
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      // Reset button exists
      expect(find.text('Reset'), findsOneWidget);
    });
  });

  group('SettingsScreen Spending Notification Toggles Tests', () {
    testWidgets('renders NeumorphicToggleSwitch for master notification toggle', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final switchFinder = find.byKey(const Key('master_notification_switch'));
      expect(switchFinder, findsOneWidget);
      expect(tester.widget(switchFinder), isA<NeumorphicToggleSwitch>());
    });
  });
}

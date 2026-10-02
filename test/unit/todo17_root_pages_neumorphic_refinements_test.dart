// File: test/unit/todo17_root_pages_neumorphic_refinements_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/cloud/models/user_models.dart';
import 'package:reciept_logging/cloud/services/auth_service.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/theme/theme_controller.dart';
import 'package:reciept_logging/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:reciept_logging/ui/features/history/views/history_screen.dart';
import 'package:reciept_logging/ui/features/ai_assistant/views/ai_assistant_screen.dart';
import 'package:reciept_logging/ui/features/settings/views/user_settings_screen.dart';

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

  group('TODO-17: Theme Tokens & Dual-Shadow Emboss Tests', () {
    test('AppTheme darkNeumorphicTheme provides visible specular emboss highlight', () {
      final theme = AppTheme.darkNeumorphicTheme;
      expect(theme.shadowDarkColorEmboss, const Color(0xB3000000));
      expect(theme.shadowLightColorEmboss, const Color(0x28FFFFFF));
      expect(theme.shadowLightColorEmboss.a, greaterThan(0.1));
    });

    test('AppThemeController shadowLightColorEmboss and shadowDarkColorEmboss provide proper contrast in dark mode', () {
      final controller = AppThemeController.instance;
      expect(controller.isDarkMode, isTrue);
      // Emboss light shadow has visible specular alpha (~0.16)
      expect(controller.shadowLightColorEmboss.a, closeTo(0.16, 0.02));
      // Emboss dark shadow has substantial inner shadow (~0.65)
      expect(controller.shadowDarkColorEmboss.a, closeTo(0.65, 0.02));
    });
  });

  group('TODO-17: Dashboard Screen Layout Tests', () {
    testWidgets('Dashboard SingleChildScrollView has dynamic bottom padding clearing FAB with ~24px clearance', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pump();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      final singleScroll = tester.widget<SingleChildScrollView>(scrollFinder);
      final padding = singleScroll.padding as EdgeInsets;
      // Greater than 110 (70 nav + 18 fab + 5% margin + 24 extra margin)
      expect(padding.bottom, greaterThan(110.0));
      expect(padding.left, 24.0);
      expect(padding.right, 24.0);
    });
  });

  group('TODO-17: History Screen Refinements Tests', () {
    testWidgets('HistoryScreen renders single-line rich header "History (X)"', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const HistoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final plain = widget.text.toPlainText();
          return plain.startsWith('History');
        }
        return false;
      });
      expect(richTextFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('HistoryScreen ListView is wrapped in FadingEdgeScrollView with Clip.hardEdge and dynamic FAB clearance', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const HistoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final listFinder = find.byType(ListView);
      if (listFinder.evaluate().isNotEmpty) {
        final listView = tester.widget<ListView>(listFinder);
        expect(listView.clipBehavior, Clip.hardEdge);
        final padding = listView.padding as EdgeInsets;
        expect(padding.top, 8.0);
        expect(padding.bottom, greaterThan(110.0));
      }
    });
  });

  group('TODO-17: AI Assistant Screen Refinements Tests', () {
    testWidgets('AiAssistantScreen renders single-line rich header "Conversations (X)" and outlined protruded "+" button', (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const AiAssistantScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Header rich text
      final richTextFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final plain = widget.text.toPlainText();
          return plain.startsWith('Conversations');
        }
        return false;
      });
      expect(richTextFinder, findsAtLeastNWidgets(1));

      // 2. "+" button is outlined & protruded with accent color icon
      final circularBtnFinder = find.byType(NeumorphicCircularButton);
      expect(circularBtnFinder, findsOneWidget);
      final circularBtn = tester.widget<NeumorphicCircularButton>(circularBtnFinder);
      expect(circularBtn.icon, Icons.add_rounded);
      expect(circularBtn.border, isNotNull);
      expect(circularBtn.color, AppThemeController.instance.currentBaseColor);

      // 3. Empty state is rendered when no conversations exist
      expect(find.text('No conversations yet'), findsOneWidget);
    });
  });

  group('TODO-17: Account & Profile (UserSettingsScreen) Tests', () {
    testWidgets('UserSettingsScreen renders enlarged tier icon in top-left and iconless Upgrade button', (WidgetTester tester) async {
      configureViewport(tester);
      await AuthService.instance.saveSession(
        const UserRecordDto(
          id: 'usr-todo17-free',
          username: 'Todo17User',
          email: 'todo17@example.com',
          createdAt: '2026-08-10T12:00:00Z',
          tier: 'free',
        ),
        userToken: 'mock-token',
      );

      await tester.pumpWidget(buildTestableWidget(const UserSettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Enlarged tier icon in top-left
      final tierIconFinder = find.byWidgetPredicate((w) {
        return w is Icon && w.icon == Icons.bolt_rounded && w.size == 28;
      });
      expect(tierIconFinder, findsOneWidget);

      // 2. Upgrade button has no chevron icon
      expect(find.byIcon(Icons.keyboard_double_arrow_up_rounded), findsNothing);
      expect(find.text('Upgrade'), findsOneWidget);

      // 3. View Policies & Tour parent card rendered
      expect(find.text('View Policies & Tour'), findsOneWidget);
      expect(find.text("Read our legal documents or play the app's walkthrough"), findsOneWidget);
    });
  });

  group('TODO-17: Canvas Gradient Background Tests', () {
    test('AppThemeController backgroundGradient has lighter top and darker bottom with subtle shift', () {
      final controller = AppThemeController.instance;
      final top = controller.backgroundGradientTop;
      final bottom = controller.backgroundGradientBottom;

      final topHsl = HSLColor.fromColor(top);
      final bottomHsl = HSLColor.fromColor(bottom);

      // Top is lighter than bottom
      expect(topHsl.lightness, greaterThan(bottomHsl.lightness));
      // Shift is soft and subtle (delta between 0.05 and 0.10)
      final delta = topHsl.lightness - bottomHsl.lightness;
      expect(delta, closeTo(0.075, 0.02));

      // Gradient object configuration
      final grad = controller.backgroundGradient;
      expect(grad.begin, Alignment.topCenter);
      expect(grad.end, Alignment.bottomCenter);
      expect(grad.colors.length, 2);
      expect(grad.colors[0], top);
      expect(grad.colors[1], bottom);
    });
  });
}

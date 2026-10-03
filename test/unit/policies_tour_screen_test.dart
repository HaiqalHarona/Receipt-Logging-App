// File: test/unit/policies_tour_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/widgets/fading_edge_scroll_view.dart';
import 'package:reciept_logging/ui/core/widgets/app_gradient_background.dart';
import 'package:reciept_logging/ui/features/settings/views/policies_tour_screen.dart';

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

  group('PoliciesTourScreen Widget Tests', () {
    testWidgets('PoliciesTourScreen renders all legal documents and app walkthrough options', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableWidget(const PoliciesTourScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Title & sections
      expect(find.text('Policies & Tour'), findsOneWidget);
      expect(find.text('LEGAL DOCUMENTS'), findsOneWidget);
      expect(find.text('APP TOUR'), findsOneWidget);

      // Legal document rows
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('GDPR, CCPA/CPRA & Zero AI Training'), findsOneWidget);

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Acceptable use & governing law'), findsOneWidget);

      expect(find.text('Cookie & Storage Policy'), findsOneWidget);
      expect(find.text('Secure tokens, cache & local database'), findsOneWidget);

      expect(find.text('Accessibility Statement'), findsOneWidget);
      expect(find.text('ADA Title III & WCAG 2.1 AA'), findsOneWidget);

      // App tour row
      expect(find.text('App Walkthrough'), findsOneWidget);
      expect(find.text('Revisit the welcome features & privacy tour'), findsOneWidget);

      // Back button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });

  group('FadingEdgeScrollView Widget Tests', () {
    testWidgets('FadingEdgeScrollView wraps child in ShaderMask', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FadingEdgeScrollView(
              child: ListView(
                children: const [
                  Text('Item 1'),
                  Text('Item 2'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });
  });

  group('AppGradientBackground Tests', () {
    testWidgets('AppGradientBackground renders Container with LinearGradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppGradientBackground(
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pump();

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final decor = container.decoration as BoxDecoration?;
      expect(decor?.gradient, isNotNull);
      expect(decor?.gradient, isA<LinearGradient>());
    });
  });
}

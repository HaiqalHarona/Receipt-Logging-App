// File: test/unit/todo17_ui_refinements_components_and_pages_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/features/history/views/widgets/category_filter_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      home: NeumorphicTheme(
        theme: const NeumorphicThemeData(
          baseColor: Color(0xFF2D3436),
          accentColor: Color(0xFF6C5CE7),
          lightSource: LightSource.topLeft,
          depth: 4,
          intensity: 0.7,
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  group('NeumorphicCircularButton Component Tests', () {
    testWidgets('renders icon and responds to tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          NeumorphicCircularButton(
            icon: Icons.arrow_back_rounded,
            iconSize: 20,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.byType(NeumorphicCircularButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders loading state when isLoading is true and ignores tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          NeumorphicCircularButton(
            icon: Icons.sync_rounded,
            isLoading: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsNothing);
      await tester.tap(find.byType(NeumorphicCircularButton));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('NeumorphicInputFieldWidget Component Tests', () {
    testWidgets('renders child and applies indented neumorphic decoration', (tester) async {
      final controller = TextEditingController(text: 'Initial text');
      await tester.pumpWidget(
        wrapWithTheme(
          NeumorphicInputFieldWidget(
            borderRadius: 14,
            child: TextField(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Initial text'), findsOneWidget);

      final neu = tester.widget<Neumorphic>(find.byType(Neumorphic));
      expect(neu.style?.depth, lessThan(0)); // Must be indented (depth < 0)
    });
  });

  group('CategoryFilterBottomSheet Checkmark Removal Tests', () {
    testWidgets('selected category chip does NOT show checkmark icon', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          CategoryFilterBottomSheet(
            availableCategories: const ['Dining', 'Groceries'],
            initialSelectedCategories: const {'Dining'},
            onApply: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dining'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      // Checkmark icon must NOT be rendered for selected category
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}

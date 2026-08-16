// File: test/unit/category_overflow_badge_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/domain/models/receipt.dart';
import 'package:reciept_logging/ui/features/history/views/widgets/receipt_list_item_widget.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Dynamic Category Tag Overflow Tests', () {
    testWidgets('ReceiptListItemWidget displays all tags with no +N badge when all fit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const receipt = Receipt(
        id: 'test-overflow-1',
        merchant: 'Store A',
        date: 'Aug 09, 2026',
        amount: 25.0,
        currency: 'USD',
        category: 'Dining, Health, Transport',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const ReceiptListItemWidget(
            receipt: receipt,
            formattedPrice: '\$25.00',
            textPrimary: Colors.white,
            textSecondary: Colors.grey,
            accent: Colors.teal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 3 tags fit in a wide viewport -> all 3 rendered, no +N badge
      expect(find.text('Dining'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('ReceiptListItemWidget displays +N badge dynamically when tags would overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const receipt = Receipt(
        id: 'test-overflow-2',
        merchant: 'Store Superstore NYC',
        date: 'Aug 09, 2026',
        amount: 150.0,
        currency: 'USD',
        category: 'Electronics, Entertainment, Utilities, Transport',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const ReceiptListItemWidget(
            receipt: receipt,
            formattedPrice: '\$150.00',
            textPrimary: Colors.white,
            textSecondary: Colors.grey,
            accent: Colors.teal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On a narrow screen with long title and 4 categories, +N badge appears
      expect(find.textContaining('+'), findsOneWidget);
    });
  });
}

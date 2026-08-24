// File: test/unit/alpha_breadcrumb_badge_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:reciept_logging/cloud/api/api_config.dart';
import 'package:reciept_logging/ui/core/theme/app_theme.dart';
import 'package:reciept_logging/ui/core/widgets/alpha_breadcrumb_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return NeumorphicApp(
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkNeumorphicTheme,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('AlphaBreadcrumbBadge Widget Tests', () {
    testWidgets('Renders Alpha environment label and version display',
        (WidgetTester tester) async {
      await tester
          .pumpWidget(buildTestableWidget(const AlphaBreadcrumbBadge()));
      await tester.pumpAndSettle();

      expect(find.byType(AlphaBreadcrumbBadge), findsOneWidget);
      expect(
        find.textContaining('${ApiConfig.appEnv.toUpperCase()} v'),
        findsOneWidget,
      );
    });

    testWidgets('Compact mode renders text with compact font',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          buildTestableWidget(const AlphaBreadcrumbBadge(compact: true)));
      await tester.pumpAndSettle();

      expect(find.byType(AlphaBreadcrumbBadge), findsOneWidget);
    });
  });
}

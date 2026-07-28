import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/main.dart';
import 'package:reciept_logging/core/providers/theme_provider.dart';

void main() {
  testWidgets('App smoke test — ReceiptLoggerApp renders in dark mode without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ReceiptLoggerApp()),
    );

    // Verify initial render on splash screen
    expect(find.byType(ReceiptLoggerApp), findsOneWidget);

    // Advance time past the 2-second splash screen transition
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    // Verify app remains active
    expect(find.byType(ReceiptLoggerApp), findsOneWidget);
  });

  testWidgets('ReceiptLoggerApp initializes with dark theme by default',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeProvider), equals(AppThemeMode.dark));
  });
}

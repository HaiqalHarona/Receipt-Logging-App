// Smoke test placeholder — updated to reference the actual app entry point.
// The original counter test is not applicable to this app.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reciept_logging/main.dart';

void main() {
  testWidgets('App smoke test — ReceiptLoggerApp renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ReceiptLoggerApp()),
    );
    // App uses GoRouter; just verify it doesn't throw on startup.
    expect(find.byType(ReceiptLoggerApp), findsOneWidget);
  });
}

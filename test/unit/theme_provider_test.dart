import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reciept_logging/ui/core/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeNotifier tests', () {
    test('Initial theme state defaults to dark mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final themeState = container.read(themeProvider);
      expect(themeState, equals(AppThemeMode.dark));
    });

    test('Toggle toggles theme from dark to light and back to dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      expect(container.read(themeProvider), equals(AppThemeMode.dark));

      notifier.toggle();
      expect(container.read(themeProvider), equals(AppThemeMode.light));

      notifier.toggle();
      expect(container.read(themeProvider), equals(AppThemeMode.dark));
    });
  });
}

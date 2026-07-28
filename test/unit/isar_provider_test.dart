import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reciept_logging/core/providers/isar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isarProvider tests', () {
    test('isarProvider handles initialization without throwing MissingPlatformDirectoryException', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify that reading the provider catches platform directory errors cleanly
      try {
        final isar = await container.read(isarProvider.future);
        expect(isar, isNotNull);
        expect(isar.isOpen, isTrue);
      } catch (e) {
        // If Isar C++ binaries are not present in test environment, it will fail on Isar.open binding
        // rather than MissingPlatformDirectoryException
        expect(e.toString(), isNot(contains('MissingPlatformDirectoryException')));
      }
    });
  });
}

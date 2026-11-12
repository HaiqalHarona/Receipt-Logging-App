// test/unit/isar_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/data/local/isar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    IsarService.resetForTesting();
  });

  group('IsarService Lifecycle & Guard Tests', () {
    test('isInitialized is false by default', () {
      expect(IsarService.isInitialized, isFalse);
    });

    test('accessing isar before initialization throws StateError with helpful message', () {
      expect(
        () => IsarService.isar,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('IsarService must be initialized before accessing isar'),
        )),
      );
    });

    test('defaultInstanceName is configured as "default"', () {
      expect(IsarService.defaultInstanceName, equals('default'));
    });

    test('close when uninitialized completes cleanly without error', () async {
      await expectLater(IsarService.close(), completes);
      expect(IsarService.isInitialized, isFalse);
    });
  });
}

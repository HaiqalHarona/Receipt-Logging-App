import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized service to manage Isar database initialization and inspector settings.
class IsarService {
  IsarService._();

  static late Isar _isar;

  /// Returns the active Isar instance.
  static Isar get isar => _isar;

  /// Initializes the Isar database.
  /// Explicitly enables the Isar Inspector in Debug mode so it connects seamlessly
  /// on physical devices and emulators.
  static Future<Isar> init({
    required List<CollectionSchema<dynamic>> schemas,
  }) async {
    if (Isar.instanceNames.contains('default')) {
      _isar = Isar.getInstance('default')!;
      return _isar;
    }

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      schemas,
      directory: dir.path,
      inspector: kDebugMode, // Ensures Isar Inspector is active in debug builds
    );

    if (kDebugMode) {
      debugPrint('🚀 [Isar] Database opened at: ${dir.path}');
      debugPrint(
        '🔍 [Isar Inspector] Open https://inspect.isar.dev in your browser.\n'
        '👉 Note for physical USB devices: Run "adb forward tcp:9000 tcp:9000" in your desktop terminal.',
      );
    }

    return _isar;
  }
}

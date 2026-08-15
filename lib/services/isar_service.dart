import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'app_logger_service.dart';

/// Centralized service to manage Isar database initialization and inspector settings.
class IsarService {
  IsarService._();

  static late Isar _isar;
  static bool _isInitialized = false;

  /// Returns whether the Isar instance has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the active Isar instance.
  static Isar get isar => _isar;

  /// Initializes the Isar database.
  /// Explicitly enables the Isar Inspector in Debug mode so it connects seamlessly
  /// on physical devices and emulators.
  static Future<Isar> init({
    required List<CollectionSchema<dynamic>> schemas,
  }) async {
    AppLogger.info(
        'Isar', 'Initializing Isar database with ${schemas.length} schemas...');
    if (Isar.instanceNames.contains('default')) {
      _isar = Isar.getInstance('default')!;
      _isInitialized = true;
      AppLogger.info('Isar', 'Reusing active Isar instance "default".');
      return _isar;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      AppLogger.debug('Isar', 'Opening Isar DB at directory: ${dir.path}');

      _isar = await Isar.open(
        schemas,
        directory: dir.path,
        inspector:
            kDebugMode, // Ensures Isar Inspector is active in debug builds
      );
      _isInitialized = true;

      AppLogger.info('Isar', '🚀 Database opened successfully at: ${dir.path}');
      if (kDebugMode) {
        AppLogger.debug(
          'Isar',
          '🔍 Isar Inspector available at https://inspect.isar.dev (Physical devices: run "adb forward tcp:9000 tcp:9000")',
        );
      }

      return _isar;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Isar', 'Failed to initialize Isar database', e, stackTrace);
      rethrow;
    }
  }
}

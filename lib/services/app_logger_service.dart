// lib/services/app_logger_service.dart
//
// Centralized togglable logger for receipt_logging_app.
// Appends timestamped, tagged human-readable logs to app.log at project root
// or application documents directory, with complete exception shielding.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static bool enableFileLogging = true;
  static bool enableConsoleLogging = true;
  static String? _resolvedLogPath;

  /// Initializes AppLogger and resolves a writable app.log file path.
  static Future<void> init() async {
    if (_resolvedLogPath != null) return;

    // 1. Try local workspace relative path first (desktop / local dev)
    try {
      final localFile = File('app.log');
      await localFile.writeAsString('', mode: FileMode.append);
      _resolvedLogPath = localFile.path;
    } catch (_) {
      // 2. Fall back to application documents directory for mobile platforms / sandboxed environments
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final docFile = File('${docsDir.path}/app.log');
        await docFile.writeAsString('', mode: FileMode.append);
        _resolvedLogPath = docFile.path;
      } catch (e) {
        debugPrint(
            '⚠️ [AppLogger] File logging disabled (no writable path available): $e');
        enableFileLogging = false;
      }
    }

    if (_resolvedLogPath != null) {
      debugPrint(
          '📝 [AppLogger] File logging initialized at: $_resolvedLogPath');
    }
  }

  void _log(LogLevel level, String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final now = DateTime.now();
    final timeStr =
        "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} "
        "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}."
        "${_threeDigits(now.millisecond)}";

    final levelStr = level.name.toUpperCase().padRight(5);
    final logLine = "$timeStr [$levelStr] [$tag] $message";

    if (enableConsoleLogging) {
      debugPrint(logLine);
      if (error != null) {
        debugPrint("   ↳ Error: $error");
      }
      if (stackTrace != null) {
        debugPrint("   ↳ StackTrace: $stackTrace");
      }
    }

    if (enableFileLogging && _resolvedLogPath != null) {
      try {
        final file = File(_resolvedLogPath!);
        final buffer = StringBuffer()..writeln(logLine);
        if (error != null) {
          buffer.writeln("   ↳ Error: $error");
        }
        if (stackTrace != null) {
          buffer.writeln("   ↳ StackTrace: $stackTrace");
        }
        file.writeAsStringSync(buffer.toString(),
            mode: FileMode.append, flush: true);
      } catch (e) {
        // Exception shield: silently catch any FileSystemException so app runtime never crashes
      }
    }
  }

  static void debug(String tag, String message) {
    instance._log(LogLevel.debug, tag, message);
  }

  static void info(String tag, String message) {
    instance._log(LogLevel.info, tag, message);
  }

  static void warning(String tag, String message, [Object? error]) {
    instance._log(LogLevel.warning, tag, message, error);
  }

  static void error(String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    instance._log(LogLevel.error, tag, message, error, stackTrace);
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}

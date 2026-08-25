// lib/services/app_logger_service.dart
//
// Centralized togglable logger for receipt_logging_app.
// Appends timestamped, tagged human-readable logs to app.log at project root
// or application documents directory, with complete exception shielding.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static bool enableFileLogging = !kReleaseMode;
  static bool enableConsoleLogging = true;
  static String? _resolvedLogPath;
  static const int _maxLogSizeBytes = 5 * 1024 * 1024; // 5 MB rotation ceiling

  static final StreamController<String> _logQueue = StreamController<String>();
  static IOSink? _sink;
  static bool _initialized = false;

  static String _sanitize(String text) {
    var sanitized = text;
    sanitized = sanitized.replaceAll(
      RegExp(r'(Bearer\s+)[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_=]*', caseSensitive: false),
      r'$1[REDACTED_JWT]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'("?password"?\s*[:=]\s*"?)([^"\s,}{]+)', caseSensitive: false),
      r'$1[REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'("?device_token"?\s*[:=]\s*"?)([^"\s,}{]+)', caseSensitive: false),
      r'$1[REDACTED]',
    );
    return sanitized;
  }

  /// Initializes AppLogger and resolves a writable app.log file path with asynchronous queue sink.
  static Future<void> init() async {
    if (_initialized) return;

    // In release mode, file logging is disabled by default for privacy
    if (kReleaseMode && !enableFileLogging) {
      _initialized = true;
      return;
    }

    // 1. Try local workspace relative path first (desktop / local dev)
    try {
      final localFile = File('app.log');
      await _prepareLogFile(localFile);
      _resolvedLogPath = localFile.path;
    } catch (_) {
      // 2. Fall back to application documents directory for mobile platforms / sandboxed environments
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final docFile = File('${docsDir.path}/app.log');
        await _prepareLogFile(docFile);
        _resolvedLogPath = docFile.path;
      } catch (e) {
        debugPrint(
            '⚠️ [AppLogger] File logging disabled (no writable path available): $e');
        enableFileLogging = false;
      }
    }

    if (_resolvedLogPath != null && enableFileLogging) {
      try {
        final file = File(_resolvedLogPath!);
        _sink = file.openWrite(mode: FileMode.append);
        _logQueue.stream.listen((logEntry) {
          _sink?.writeln(logEntry);
        });
        _initialized = true;
        debugPrint('📝 [AppLogger] Async file logging initialized at: $_resolvedLogPath');
      } catch (e) {
        debugPrint('⚠️ [AppLogger] Failed to open log sink: $e');
      }
    }
  }

  static Future<void> _prepareLogFile(File file) async {
    if (await file.exists()) {
      final length = await file.length();
      if (length > _maxLogSizeBytes) {
        final oldFile = File('${file.path}.old');
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
        await file.rename(oldFile.path);
      }
    }
    await file.writeAsString('', mode: FileMode.append);
  }

  void _log(LogLevel level, String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final now = DateTime.now();
    final timeStr =
        "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} "
        "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}."
        "${_threeDigits(now.millisecond)}";

    final levelStr = level.name.toUpperCase().padRight(5);
    final cleanMessage = _sanitize(message);
    final logLine = "$timeStr [$levelStr] [$tag] $cleanMessage";

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
        final buffer = StringBuffer()..write(logLine);
        if (error != null) {
          buffer.write("\n   ↳ Error: $error");
        }
        if (stackTrace != null) {
          buffer.write("\n   ↳ StackTrace: $stackTrace");
        }
        _logQueue.add(buffer.toString());
      } catch (_) {
        // Shield against queue errors
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

  static Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}

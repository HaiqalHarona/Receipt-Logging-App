import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reciept_logging/data/models/receipt.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final existing = Isar.getInstance();
  if (existing != null && existing.isOpen) {
    return existing;
  }

  String dirPath;
  try {
    final dir = await getApplicationDocumentsDirectory();
    dirPath = dir.path;
  } catch (_) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final fallbackDir = Directory('$home/.local/share/reciept_logging');
    if (!fallbackDir.existsSync()) {
      fallbackDir.createSync(recursive: true);
    }
    dirPath = fallbackDir.path;
  }

  return Isar.open(
    [ReceiptSchema],
    directory: dirPath,
  );
});

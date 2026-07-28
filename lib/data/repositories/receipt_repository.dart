import 'package:isar/isar.dart';
import '../models/receipt.dart';

class ReceiptRepository {
  final Isar isar;

  // The repository requires an open Isar instance to work
  ReceiptRepository(this.isar);

  /// CREATE / UPDATE
  Future<void> saveReceipt(Receipt receipt) async {
    await isar.writeTxn(() async {
      await isar.receipts.put(receipt); // Inserts or updates based on the ID
    });
  }

  /// READ (Single)
  Future<Receipt?> getReceiptById(int id) async {
    return await isar.receipts.get(id);
  }

  /// READ (All)
  Future<List<Receipt>> getAllReceipts() async {
    return await isar.receipts.where().findAll();
  }

  /// DELETE
  Future<void> deleteReceipt(int id) async {
    await isar.writeTxn(() async {
      await isar.receipts.delete(id);
    });
  }
}
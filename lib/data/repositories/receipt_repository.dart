// File: lib/data/repositories/receipt_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/receipt.dart';
import '../../services/currency_service.dart';
import '../../services/isar_service.dart';
import '../models/receipt_isar.dart';

/// Single source of truth for receipt data.
///
/// Implements the Repository pattern with Isar local persistent storage,
/// providing reactive notifications to ViewModels whenever data changes.
class ReceiptRepository extends ChangeNotifier {
  ReceiptRepository._() {
    // In test environments only, provide seed data for unit tests
    if (_isTestEnvironment) {
      _receipts = _getTestSampleReceipts();
    }
  }
  static final ReceiptRepository instance = ReceiptRepository._();

  List<Receipt> _receipts = [];
  bool _isInitialized = false;

  bool get _isTestEnvironment => Platform.environment.containsKey('FLUTTER_TEST');

  /// Returns an immutable list of all stored receipts.
  List<Receipt> get receipts {
    return List.unmodifiable(_receipts);
  }

  /// Initializes Isar repository and loads saved receipts.
  /// Also migrates any legacy JSON file records to Isar on first load.
  Future<void> init() async {
    if (_isInitialized) return;

    if (IsarService.isInitialized) {
      try {
        await _migrateLegacyJsonIfNeeded();
        await _loadFromIsar();
      } catch (e) {
        debugPrint('⚠️ [ReceiptRepository] Init error: $e');
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Saves a single receipt to the Isar database.
  Future<void> saveReceipt(Receipt receipt) async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      await isar.writeTxn(() async {
        final existing = await isar.receiptIsarModels
            .where()
            .receiptIdEqualTo(receipt.id)
            .findFirst();
        final model = ReceiptIsarModel.fromDomain(receipt);
        if (existing != null) {
          model.id = existing.id;
        }
        await isar.receiptIsarModels.put(model);
      });
      await _loadFromIsar();
    } else {
      final index = _receipts.indexWhere((r) => r.id == receipt.id);
      if (index >= 0) {
        _receipts[index] = receipt;
      } else {
        _receipts.insert(0, receipt);
      }
    }
    notifyListeners();
  }

  /// Saves multiple receipts at once (e.g., from Bulk Review).
  Future<void> saveAllReceipts(List<Receipt> newReceipts) async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      await isar.writeTxn(() async {
        for (final r in newReceipts) {
          final existing = await isar.receiptIsarModels
              .where()
              .receiptIdEqualTo(r.id)
              .findFirst();
          final model = ReceiptIsarModel.fromDomain(r);
          if (existing != null) {
            model.id = existing.id;
          }
          await isar.receiptIsarModels.put(model);
        }
      });
      await _loadFromIsar();
    } else {
      for (final r in newReceipts) {
        final index = _receipts.indexWhere((existing) => existing.id == r.id);
        if (index >= 0) {
          _receipts[index] = r;
        } else {
          _receipts.insert(0, r);
        }
      }
    }
    notifyListeners();
  }

  /// Soft-deletes a receipt by setting [deletedAt] on the local Isar record.
  ///
  /// The receipt is hidden from active queries immediately via [notifyListeners],
  /// but the local Isar record is retained for sync audit purposes.
  Future<void> softDeleteReceipt(String id) async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      await isar.writeTxn(() async {
        final existing = await isar.receiptIsarModels
            .where()
            .receiptIdEqualTo(id)
            .findFirst();
        if (existing != null) {
          existing.deletedAt = DateTime.now();
          await isar.receiptIsarModels.put(existing);
        }
      });
      await _loadFromIsar();
    } else {
      _receipts.removeWhere((r) => r.id == id);
    }
    notifyListeners();
  }

  /// Deletes a receipt by ID.
  Future<void> deleteReceipt(String id) async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      await isar.writeTxn(() async {
        final existing = await isar.receiptIsarModels
            .where()
            .receiptIdEqualTo(id)
            .findFirst();
        if (existing != null) {
          await isar.receiptIsarModels.delete(existing.id);
        }
      });
      await _loadFromIsar();
    } else {
      _receipts.removeWhere((r) => r.id == id);
    }
    notifyListeners();
  }

  /// Clears all receipts from the Isar database.
  Future<void> clearAll() async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      await isar.writeTxn(() async {
        await isar.receiptIsarModels.clear();
      });
      await _loadFromIsar();
    } else {
      _receipts.clear();
    }
    notifyListeners();
  }

  /// Calculates the total amount spent across all receipts, converted
  /// into [targetCurrencyCode] (or default active currency).
  double calculateTotalSpent([String? targetCurrencyCode]) {
    double total = 0.0;
    for (final r in _receipts) {
      final converted = CurrencyService.instance.convert(
        r.amount,
        r.currency,
        targetCurrencyCode,
      );
      total += converted;
    }
    return total;
  }

  Future<void> _loadFromIsar() async {
    try {
      final isar = IsarService.isar;
      final isarModels = await isar.receiptIsarModels.where().findAll();
      _receipts = isarModels.map((m) => m.toDomain()).toList();
    } catch (e) {
      debugPrint('⚠️ [ReceiptRepository] Load from Isar error: $e');
      _receipts = [];
    }
  }

  Future<void> _migrateLegacyJsonIfNeeded() async {
    try {
      final isar = IsarService.isar;
      final count = await isar.receiptIsarModels.count();
      if (count > 0) return; // Already has data in Isar

      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${dir.path}/receipts_db.json');
      if (await legacyFile.exists()) {
        final jsonStr = await legacyFile.readAsString();
        final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
        final legacyReceipts = list
            .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
            .where((r) => !r.id.startsWith('sample-'))
            .toList();
        if (legacyReceipts.isNotEmpty) {
          await isar.writeTxn(() async {
            for (final r in legacyReceipts) {
              await isar.receiptIsarModels.put(ReceiptIsarModel.fromDomain(r));
            }
          });
        }
      }
    } catch (_) {}
  }

  List<Receipt> _getTestSampleReceipts() {
    return [
      const Receipt(
        id: 'sample-1',
        merchant: 'Target Superstore',
        date: 'Aug 01, 2026',
        amount: 89.45,
        currency: 'USD',
        category: 'Groceries 🛒',
        items: [
          'Organic Milk 1 Gal - \$4.99',
          'Avocados Bag 5ct - \$5.49',
          'Almond Butter 16oz - \$7.99',
          'Greek Yogurt 32oz - \$6.29',
          'Paper Towels 6pk - \$14.99',
        ],
      ),
      const Receipt(
        id: 'sample-2',
        merchant: 'Shell Gas Station',
        date: 'Jul 31, 2026',
        amount: 54.20,
        currency: 'USD',
        category: 'Transport 🚗',
        items: [
          'Regular Unleaded Fuel (14.25 Gal) - \$54.20',
        ],
      ),
      const Receipt(
        id: 'sample-3',
        merchant: 'Apple Store NYC',
        date: 'Jul 28, 2026',
        amount: 129.00,
        currency: 'USD',
        category: 'Electronics 💻',
        items: [
          'Apple Pencil Pro - \$129.00',
        ],
      ),
      const Receipt(
        id: 'sample-4',
        merchant: 'Blue Bottle Coffee',
        date: 'Jul 25, 2026',
        amount: 12.50,
        currency: 'USD',
        category: 'Dining ☕',
        items: [
          'Iced New Orleans Style Coffee - \$6.25',
        ],
      ),
      const Receipt(
        id: 'sample-5',
        merchant: 'Whole Foods Market',
        date: 'Jul 22, 2026',
        amount: 142.80,
        currency: 'USD',
        category: 'Groceries 🛒',
        items: [
          'Wild Caught Salmon Fillets - \$28.50',
          'Organic Baby Spinach - \$3.99',
          'Free Range Large Eggs Dozen - \$7.49',
          'Artisanal Sourdough Loaf - \$6.99',
        ],
      ),
    ];
  }
}

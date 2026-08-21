// File: lib/data/repositories/receipt_repository.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/line_item.dart';
import '../../domain/models/receipt.dart';
import '../../services/app_logger_service.dart';
import '../../services/currency_service.dart';
import '../../services/isar_service.dart';
import '../models/receipt_isar.dart';
import '../../cloud/api/backend_api_client.dart';
import '../../cloud/models/receipt_models.dart';
import '../../cloud/services/auth_service.dart';
import '../../ui/core/utils/category_utils.dart';

/// Single source of truth for receipt data.
///
/// Implements the Repository pattern with Isar local persistent storage,
/// providing reactive notifications to ViewModels whenever data changes.
class ReceiptRepository extends ChangeNotifier {
  ReceiptRepository._() {
    // In test environments only, provide seed data for unit tests
    if (_isTestEnvironment) {
      _receipts = List.of(_getTestSampleReceipts());
    }
    AuthService.instance.addListener(() {
      notifyListeners();
    });
  }
  static final ReceiptRepository instance = ReceiptRepository._();

  List<Receipt> _receipts = [];
  bool _isInitialized = false;

  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Returns an immutable list of all stored receipts.
  /// When unauthenticated (guest mode), filters out any cloud receipts with UUIDs.
  List<Receipt> get receipts {
    if (!AuthService.instance.isLoggedIn) {
      return List.unmodifiable(_receipts.where((r) => !_isUuid(r.id)));
    }
    return List.unmodifiable(_receipts);
  }

  /// Initializes Isar repository and loads saved receipts.
  /// Also migrates any legacy JSON file records to Isar on first load.
  Future<void> init() async {
    if (_isInitialized && _receipts.isNotEmpty) return;
    AppLogger.info('Isar', '[ReceiptRepository] Initializing repository...');

    if (IsarService.isInitialized) {
      try {
        await _migrateLegacyJsonIfNeeded();
        await _loadFromIsar();
        _isInitialized = true;
        AppLogger.info('Isar',
            '[ReceiptRepository] Initialized successfully with ${_receipts.length} receipts.');
      } catch (e, stackTrace) {
        AppLogger.error(
            'Isar', '[ReceiptRepository] Init error', e, stackTrace);
      }
    } else {
      AppLogger.warning('Isar',
          '[ReceiptRepository] IsarService not initialized yet; deferring init.');
    }
    notifyListeners();
  }

  /// Saves a single receipt to the Isar database.
  Future<void> saveReceipt(Receipt receipt) async {
    final receiptToSave = receipt.createdAt != null
        ? receipt
        : receipt.copyWith(createdAt: DateTime.now());
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      AppLogger.info('Isar',
          '[ReceiptRepository] Transaction write: saving receipt ${receiptToSave.id} (${receiptToSave.merchant})');
      await isar.writeTxn(() async {
        final existing = await isar.receiptIsarModels
            .where()
            .receiptIdEqualTo(receiptToSave.id)
            .findFirst();
        final model = ReceiptIsarModel.fromDomain(receiptToSave);
        if (existing != null) {
          model.id = existing.id;
          if (receipt.createdAt == null) {
            model.createdAt = existing.createdAt;
          }
        }
        await isar.receiptIsarModels.put(model);
      });
      AppLogger.debug('Isar',
          '[ReceiptRepository] Saved receipt ${receiptToSave.id} to Isar DB.');
      await _loadFromIsar();
    } else {
      final index = _receipts.indexWhere((r) => r.id == receiptToSave.id);
      if (index >= 0) {
        _receipts[index] = receiptToSave;
      } else {
        _receipts.insert(0, receiptToSave);
      }
      AppLogger.debug('Isar',
          '[ReceiptRepository] Saved receipt ${receiptToSave.id} to in-memory store.');
    }
    notifyListeners();
    _createInCloudIfLoggedIn(receiptToSave);
  }

  /// Saves multiple receipts at once (e.g., from Bulk Review).
  Future<void> saveAllReceipts(List<Receipt> newReceipts) async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      AppLogger.info('Isar',
          '[ReceiptRepository] Transaction write: batch saving ${newReceipts.length} receipts');
      await isar.writeTxn(() async {
        for (final r in newReceipts) {
          final receiptToSave =
              r.createdAt != null ? r : r.copyWith(createdAt: DateTime.now());
          final existing = await isar.receiptIsarModels
              .where()
              .receiptIdEqualTo(receiptToSave.id)
              .findFirst();
          final model = ReceiptIsarModel.fromDomain(receiptToSave);
          if (existing != null) {
            model.id = existing.id;
            if (r.createdAt == null) {
              model.createdAt = existing.createdAt;
            }
          }
          await isar.receiptIsarModels.put(model);
        }
      });
      AppLogger.debug('Isar',
          '[ReceiptRepository] Batch saved ${newReceipts.length} receipts to Isar DB.');
      await _loadFromIsar();
    } else {
      for (final r in newReceipts) {
        final receiptToSave =
            r.createdAt != null ? r : r.copyWith(createdAt: DateTime.now());
        final index =
            _receipts.indexWhere((existing) => existing.id == receiptToSave.id);
        if (index >= 0) {
          _receipts[index] = receiptToSave;
        } else {
          _receipts.insert(0, receiptToSave);
        }
      }
      AppLogger.debug('Isar',
          '[ReceiptRepository] Batch saved ${newReceipts.length} receipts to in-memory store.');
    }
    notifyListeners();
    for (final r in newReceipts) {
      if (!_isUuid(r.id)) {
        _createInCloudIfLoggedIn(r);
      }
    }
  }

  bool _isUuid(String id) {
    if (id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  void _createInCloudIfLoggedIn(Receipt receipt) {
    if (!_isUuid(receipt.id) && AuthService.instance.isLoggedIn) {
      final username = AuthService.instance.currentUsername;
      final userToken = AuthService.instance.currentUserToken;
      if (username != null && userToken != null) {
        AppLogger.info('CloudSync',
            '[ReceiptRepository] Triggering backend POST /receipts/ on Supabase for ${receipt.id} (${receipt.merchant})...');
        BackendApiClient.instance
            .saveReceipt(
          receipt: ReceiptDto.fromDomain(receipt),
          username: username,
          userToken: userToken,
        )
            .then((record) async {
          AppLogger.info('CloudSync',
              '[ReceiptRepository] Cloud receipt created on Supabase (id=${record.id}, orig=${receipt.id}). Updating local Isar DB...');
          final r = record.receipt;
          final syncedReceipt = Receipt(
            id: record.id,
            merchant: r.merchantName,
            date: r.date,
            amount: r.totalAmount,
            currency: r.currency,
            category: r.category ?? '',
            createdAt: DateTime.tryParse(record.createdAt)?.toUtc() ??
                receipt.createdAt ??
                DateTime.now(),
            imagePath: receipt.imagePath,
            items: receipt.items,
            lineItems: r.lineItems
                .map((l) => LineItem(
                      description: l.description,
                      quantity: l.quantity,
                      unitPrice: l.unitPrice,
                      totalPrice: l.totalPrice,
                    ))
                .toList(),
          );

          if (IsarService.isInitialized) {
            final isar = IsarService.isar;
            await isar.writeTxn(() async {
              final oldModel = await isar.receiptIsarModels
                  .where()
                  .receiptIdEqualTo(receipt.id)
                  .findFirst();
              if (oldModel != null) {
                await isar.receiptIsarModels.delete(oldModel.id);
              }
              final newModel = ReceiptIsarModel.fromDomain(syncedReceipt);
              await isar.receiptIsarModels.put(newModel);
            });
            await _loadFromIsar();
            notifyListeners();
          } else {
            final index = _receipts.indexWhere((r) => r.id == receipt.id);
            if (index >= 0) {
              _receipts[index] = syncedReceipt;
            } else {
              _receipts.insert(0, syncedReceipt);
            }
            notifyListeners();
          }
        }).catchError((e, st) {
          AppLogger.error(
              'CloudSync',
              '[ReceiptRepository] Error executing POST /receipts/ for ${receipt.id}',
              e,
              st);
        });
      }
    }
  }

  void _updateCloudIfSynced(Receipt receipt) {
    if (_isUuid(receipt.id) && AuthService.instance.isLoggedIn) {
      final username = AuthService.instance.currentUsername;
      final userToken = AuthService.instance.currentUserToken;
      if (username != null && userToken != null) {
        AppLogger.info('CloudSync',
            '[ReceiptRepository] Triggering backend PATCH /receipts/${receipt.id} on Supabase...');
        BackendApiClient.instance
            .updateReceipt(
          receiptId: receipt.id,
          receipt: ReceiptDto.fromDomain(receipt),
          username: username,
          userToken: userToken,
        )
            .then((record) {
          AppLogger.info('CloudSync',
              '[ReceiptRepository] Cloud receipt ${receipt.id} updated on Supabase (id=${record.id}).');
        }).catchError((e, st) {
          AppLogger.error(
              'CloudSync',
              '[ReceiptRepository] Error executing PATCH /receipts/${receipt.id}',
              e,
              st);
        });
      }
    }
  }

  /// Updates a receipt in local Isar and triggers an async PATCH to Supabase when logged in.
  Future<void> updateReceipt(Receipt receipt) async {
    await saveReceipt(receipt);
    _updateCloudIfSynced(receipt);
  }

  /// Removes a category tag from all stored receipts.
  /// If a receipt only has this category, it falls back to 'General' (or empty string if 'General').
  /// Automatically updates Isar and syncs affected receipts to Supabase when logged in.
  Future<void> removeCategoryFromAllReceipts(String categoryToRemove) async {
    final cleanTarget = CategoryUtils.sanitize(categoryToRemove).toLowerCase();
    if (cleanTarget.isEmpty) return;

    final List<Receipt> affected = [];

    for (final r in _receipts) {
      final categories = r.category
          .split(',')
          .map((c) => CategoryUtils.sanitize(c).trim())
          .where((c) => c.isNotEmpty)
          .toList();

      final matchingIndex = categories.indexWhere(
          (c) => CategoryUtils.sanitize(c).toLowerCase() == cleanTarget);

      if (matchingIndex >= 0) {
        categories.removeAt(matchingIndex);
        final newCategoryString = categories.isEmpty
            ? (cleanTarget == 'general' ? '' : 'General')
            : categories.join(', ');

        final updatedReceipt = r.copyWith(category: newCategoryString);
        affected.add(updatedReceipt);
      }
    }

    if (affected.isNotEmpty) {
      for (final updated in affected) {
        await updateReceipt(updated);
      }
      AppLogger.info('Isar',
          '[ReceiptRepository] Removed category "$categoryToRemove" from ${affected.length} receipts.');
    }
  }

  void _deleteFromCloudIfSynced(String id) {
    if (_isUuid(id) && AuthService.instance.isLoggedIn) {
      final username = AuthService.instance.currentUsername;
      final userToken = AuthService.instance.currentUserToken;
      if (username != null && userToken != null) {
        AppLogger.info('CloudSync',
            '[ReceiptRepository] Triggering backend DELETE /receipts/$id on Supabase...');
        BackendApiClient.instance
            .deleteReceipt(
          receiptId: id,
          username: username,
          userToken: userToken,
        )
            .then((success) {
          if (success) {
            AppLogger.info('CloudSync',
                '[ReceiptRepository] Cloud receipt $id deleted on Supabase.');
          } else {
            AppLogger.warning('CloudSync',
                '[ReceiptRepository] Backend DELETE /receipts/$id returned false.');
          }
        }).catchError((e, st) {
          AppLogger.error(
              'CloudSync',
              '[ReceiptRepository] Error executing DELETE /receipts/$id',
              e,
              st);
        });
      }
    }
  }

  /// Soft-deletes a receipt by setting [deletedAt] on the local Isar record.
  ///
  /// The receipt is hidden from active queries immediately via [notifyListeners],
  /// but the local Isar record is retained for sync audit purposes.
  Future<void> softDeleteReceipt(String id) async {
    _deleteFromCloudIfSynced(id);
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      AppLogger.info('Isar',
          '[ReceiptRepository] Transaction write: soft deleting receipt $id');
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
      AppLogger.debug(
          'Isar', '[ReceiptRepository] Soft deleted receipt $id in Isar DB.');
      await _loadFromIsar();
    } else {
      _receipts.removeWhere((r) => r.id == id);
      AppLogger.debug('Isar',
          '[ReceiptRepository] Soft deleted receipt $id from in-memory store.');
    }
    notifyListeners();
  }

  /// Deletes a receipt by ID.
  Future<void> deleteReceipt(String id) async {
    _deleteFromCloudIfSynced(id);
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      AppLogger.info('Isar',
          '[ReceiptRepository] Transaction write: deleting receipt $id');
      await isar.writeTxn(() async {
        final existing = await isar.receiptIsarModels
            .where()
            .receiptIdEqualTo(id)
            .findFirst();
        if (existing != null) {
          await isar.receiptIsarModels.delete(existing.id);
        }
      });
      AppLogger.debug('Isar',
          '[ReceiptRepository] Permanently deleted receipt $id from Isar DB.');
      await _loadFromIsar();
    } else {
      _receipts.removeWhere((r) => r.id == id);
      AppLogger.debug('Isar',
          '[ReceiptRepository] Permanently deleted receipt $id from in-memory store.');
    }
    notifyListeners();
  }

  /// Clears all receipts from the Isar database.
  Future<void> clearAll() async {
    if (IsarService.isInitialized) {
      final isar = IsarService.isar;
      AppLogger.info('Isar',
          '[ReceiptRepository] Transaction write: clearing receiptIsarModels collection');
      await isar.writeTxn(() async {
        await isar.receiptIsarModels.clear();
      });
      AppLogger.debug(
          'Isar', '[ReceiptRepository] Cleared all receipts from Isar DB.');
      await _loadFromIsar();
    } else {
      _receipts.clear();
      AppLogger.debug('Isar',
          '[ReceiptRepository] Cleared all receipts from in-memory store.');
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
      AppLogger.debug('Isar',
          '[ReceiptRepository] Query result: fetched ${isarModels.length} receiptIsarModels from Isar DB.');
      _receipts = isarModels.map((m) => m.toDomain()).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Isar', '[ReceiptRepository] Load from Isar error', e, stackTrace);
      _receipts = [];
    }
  }

  Future<void> _migrateLegacyJsonIfNeeded() async {
    try {
      final isar = IsarService.isar;
      final count = await isar.receiptIsarModels.count();
      AppLogger.debug('Isar',
          '[ReceiptRepository] Query result: receipt count in Isar DB is $count.');
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
          AppLogger.info('Isar',
              '[ReceiptRepository] Transaction write: migrating ${legacyReceipts.length} legacy receipts to Isar DB');
          await isar.writeTxn(() async {
            for (final r in legacyReceipts) {
              await isar.receiptIsarModels.put(ReceiptIsarModel.fromDomain(r));
            }
          });
          AppLogger.debug('Isar',
              '[ReceiptRepository] Successfully migrated legacy receipts to Isar DB.');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
          'Isar', '[ReceiptRepository] Migration error', e, stackTrace);
    }
  }

  List<Receipt> _getTestSampleReceipts() {
    return const [
      Receipt(
        id: 'sample-1',
        merchant: 'Target Superstore',
        date: 'Aug 01, 2026',
        amount: 89.45,
        currency: 'USD',
        category: 'Groceries',
        items: [
          'Organic Milk 1 Gal - \$4.99',
          'Avocados Bag 5ct - \$5.49',
          'Almond Butter 16oz - \$7.99',
          'Greek Yogurt 32oz - \$6.29',
          'Paper Towels 6pk - \$14.99',
        ],
        lineItems: [
          LineItem(
              description: 'Organic Milk 1 Gal',
              quantity: 1,
              unitPrice: 4.99,
              totalPrice: 4.99),
          LineItem(
              description: 'Avocados Bag 5ct',
              quantity: 1,
              unitPrice: 5.49,
              totalPrice: 5.49),
          LineItem(
              description: 'Almond Butter 16oz',
              quantity: 1,
              unitPrice: 7.99,
              totalPrice: 7.99),
          LineItem(
              description: 'Greek Yogurt 32oz',
              quantity: 1,
              unitPrice: 6.29,
              totalPrice: 6.29),
          LineItem(
              description: 'Paper Towels 6pk',
              quantity: 1,
              unitPrice: 14.99,
              totalPrice: 14.99),
        ],
      ),
      Receipt(
        id: 'sample-2',
        merchant: 'Shell Gas Station',
        date: 'Jul 31, 2026',
        amount: 54.20,
        currency: 'USD',
        category: 'Transport',
        items: [
          'Regular Unleaded Fuel (14.25 Gal) - \$54.20',
        ],
        lineItems: [
          LineItem(
              description: 'Regular Unleaded Fuel (14.25 Gal)',
              quantity: 1,
              unitPrice: 54.20,
              totalPrice: 54.20),
        ],
      ),
      Receipt(
        id: 'sample-3',
        merchant: 'Apple Store NYC',
        date: 'Jul 28, 2026',
        amount: 129.00,
        currency: 'USD',
        category: 'Electronics',
        items: [
          'Apple Pencil Pro - \$129.00',
        ],
        lineItems: [
          LineItem(
              description: 'Apple Pencil Pro',
              quantity: 1,
              unitPrice: 129.00,
              totalPrice: 129.00),
        ],
      ),
      Receipt(
        id: 'sample-4',
        merchant: 'Blue Bottle Coffee',
        date: 'Jul 25, 2026',
        amount: 12.50,
        currency: 'USD',
        category: 'Dining',
        items: [
          'Iced New Orleans Style Coffee - \$6.25',
        ],
        lineItems: [
          LineItem(
              description: 'Iced New Orleans Style Coffee',
              quantity: 2,
              unitPrice: 6.25,
              totalPrice: 12.50),
        ],
      ),
      Receipt(
        id: 'sample-5',
        merchant: 'Whole Foods Market',
        date: 'Jul 22, 2026',
        amount: 142.80,
        currency: 'USD',
        category: 'Groceries',
        items: [
          'Wild Caught Salmon Fillets - \$28.50',
          'Organic Baby Spinach - \$3.99',
          'Free Range Large Eggs Dozen - \$7.49',
          'Artisanal Sourdough Loaf - \$6.99',
        ],
        lineItems: [
          LineItem(
              description: 'Wild Caught Salmon Fillets',
              quantity: 1,
              unitPrice: 28.50,
              totalPrice: 28.50),
          LineItem(
              description: 'Organic Baby Spinach',
              quantity: 1,
              unitPrice: 3.99,
              totalPrice: 3.99),
          LineItem(
              description: 'Free Range Large Eggs Dozen',
              quantity: 1,
              unitPrice: 7.49,
              totalPrice: 7.49),
          LineItem(
              description: 'Artisanal Sourdough Loaf',
              quantity: 1,
              unitPrice: 6.99,
              totalPrice: 6.99),
        ],
      ),
    ];
  }
}

// File: lib/data/models/receipt_isar.dart
import 'package:isar/isar.dart';
import '../../domain/models/receipt.dart';

part 'receipt_isar.g.dart';

@collection
class ReceiptIsarModel {
  Id id = Isar.autoIncrement;

  /// Unique business-key index with replace semantics:
  /// inserting a duplicate receiptId silently updates the existing record.
  @Index(unique: true, replace: true)
  late String receiptId;

  /// Secondary value index — enables fast `merchantEqualTo` / `merchantStartsWith` queries.
  @Index(type: IndexType.value)
  late String merchant;

  /// Secondary value index — enables fast date-equality and range queries.
  @Index(type: IndexType.value)
  late String date;

  late double amount;
  late String currency;

  /// Secondary value index — enables fast per-category filtering.
  @Index(type: IndexType.value)
  late String category;

  String? imagePath;
  List<String> items = [];

  ReceiptIsarModel();

  factory ReceiptIsarModel.fromDomain(Receipt receipt) {
    return ReceiptIsarModel()
      ..receiptId = receipt.id
      ..merchant = receipt.merchant
      ..date = receipt.date
      ..amount = receipt.amount
      ..currency = receipt.currency
      ..category = receipt.category
      ..imagePath = receipt.imagePath
      ..items = receipt.items;
  }

  Receipt toDomain() {
    return Receipt(
      id: receiptId,
      merchant: merchant,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      imagePath: imagePath,
      items: items,
    );
  }
}

// ── SAFE QUERY EXTENSIONS ────────────────────────────────────────────────────
//
// These typed helpers sit on top of the generated QueryBuilder so callers
// never have to re-type raw string comparisons or forget caseSensitive flags.

extension ReceiptIsarQueryFilters
    on QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QFilterCondition> {
  /// Filter receipts whose category equals [cat] (case-insensitive).
  QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QAfterFilterCondition>
      byCategoryName(String cat) => categoryEqualTo(cat, caseSensitive: false);

  /// Filter receipts whose merchant name starts with [prefix] (case-insensitive).
  /// Useful for incremental search.
  QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QAfterFilterCondition>
      byMerchantPrefix(String prefix) =>
          merchantStartsWith(prefix, caseSensitive: false);

  /// Filter receipts whose merchant name exactly matches [name] (case-insensitive).
  QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QAfterFilterCondition>
      byMerchantName(String name) =>
          merchantEqualTo(name, caseSensitive: false);

  /// Filter receipts for a specific display-date string (e.g. "Aug 01, 2026").
  QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QAfterFilterCondition>
      byDate(String displayDate) => dateEqualTo(displayDate);
}

// lib/data/models/receipt_isar.dart
//
// Isar collection model for receipts — mirrors the Supabase `receipts` table
// and the nested `receipt` JSONB object 1-to-1.
//
// Column alignment:
//   receipts.id                     → receiptId  (@Index unique+replace)
//   receipts.receipt.merchant_name  → merchant   (@Index value)
//   receipts.receipt.date           → date       (@Index value)
//   receipts.receipt.total_amount   → totalAmount
//   receipts.receipt.subtotal       → subtotal   (nullable)
//   receipts.receipt.tax_amount     → taxAmount  (nullable)
//   receipts.receipt.currency       → currency
//   receipts.receipt.category       → category   (@Index value)
//   receipts.receipt.raw_text       → rawText    (nullable)
//   receipts.receipt.confidence_score → confidenceScore (nullable)
//   receipts.receipt.line_items     → lineItems  (@embedded LineItemIsarModel list)
//   receipts.created_at             → createdAt  (@Index DateTime)
//   receipts.deleted_at             → deletedAt  (@Index DateTime? — null = active)
//
// Legacy flat `items` list is retained for backward-compatibility with
// any existing local data written before this schema migration.

import 'package:isar/isar.dart';
import 'line_item_isar.dart';
import '../../domain/models/receipt.dart';
import '../../data/mappers/line_item_mapper.dart';
import '../../ui/core/utils/category_utils.dart';

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

  late double totalAmount;
  double? subtotal;
  double? taxAmount;
  late String currency;

  /// Secondary value index — enables fast per-category filtering.
  @Index(type: IndexType.value)
  late String category;

  String? imagePath;
  String? rawText;
  double? confidenceScore;

  /// Embedded line-items list — mirrors receipt.line_items JSONB array.
  List<LineItemIsarModel> lineItems = [];

  /// Legacy flat string items list retained for backward-compatibility.
  List<String> items = [];

  /// Native DateTime index for sorting and date range queries.
  @Index()
  DateTime createdAt = DateTime.now();

  /// Soft-delete timestamp — null means the record is active.
  @Index()
  DateTime? deletedAt;

  ReceiptIsarModel();

  factory ReceiptIsarModel.fromDomain(Receipt receipt) {
    return ReceiptIsarModel()
      ..receiptId = receipt.id
      ..merchant = receipt.merchant
      ..date = receipt.date
      ..totalAmount = receipt.amount
      ..currency = receipt.currency
      ..category = receipt.category
          .split(',')
          .map((c) => CategoryUtils.sanitize(c))
          .where((c) => c.isNotEmpty)
          .join(', ')
      ..imagePath = receipt.imagePath
      ..createdAt = receipt.createdAt ?? DateTime.now()
      ..items = receipt.items
      ..lineItems = receipt.lineItems.map((li) => li.toIsar()).toList();
  }

  Receipt toDomain() {
    var domainLineItems = lineItems.map((li) => li.toDomain()).toList();
    if (domainLineItems.isEmpty && items.isNotEmpty) {
      domainLineItems = Receipt.parseLegacyItemsToLineItems(items);
    }

    final sanitizedCat = category
        .split(',')
        .map((c) => CategoryUtils.sanitize(c))
        .where((c) => c.isNotEmpty)
        .join(', ');

    return Receipt(
      id: receiptId,
      merchant: merchant,
      date: date,
      amount: totalAmount,
      currency: currency,
      category: sanitizedCat,
      imagePath: imagePath,
      createdAt: createdAt,
      items: items,
      lineItems: domainLineItems,
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

  /// Filter active (non-deleted) receipts only.
  QueryBuilder<ReceiptIsarModel, ReceiptIsarModel, QAfterFilterCondition>
      activeOnly() => deletedAtIsNull();
}

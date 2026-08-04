// lib/data/models/line_item_isar.dart
//
// @embedded Isar model mirroring the `line_items` array within the
// Supabase `receipts.receipt` JSONB column.
//
// @embedded classes are stored inline inside their parent collection
// (ReceiptIsarModel) — no separate collection table is created.

import 'package:isar/isar.dart';

part 'line_item_isar.g.dart';

@embedded
class LineItemIsarModel {
  String description = '';
  double? quantity;
  double? unitPrice;
  double? totalPrice;

  LineItemIsarModel({
    this.description = '',
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });
}

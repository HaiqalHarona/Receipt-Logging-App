// lib/domain/models/line_item.dart

import 'package:flutter/foundation.dart';

/// Pure immutable domain model for a single receipt line item.
///
/// Mirrors [LineItemIsarModel] and [LineItemDto] but is decoupled
/// from both — conversions are handled by [lib/data/mappers/line_item_mapper.dart].
@immutable
class LineItem {
  final String description;
  final double? quantity;
  final double? unitPrice;
  final double? totalPrice;

  const LineItem({
    required this.description,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  LineItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return LineItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  /// Returns the best available price for this line item.
  double get effectivePrice {
    if (totalPrice != null) return totalPrice!;
    if (unitPrice != null && quantity != null) return unitPrice! * quantity!;
    if (unitPrice != null) return unitPrice!;
    return 0.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineItem &&
          runtimeType == other.runtimeType &&
          description == other.description &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice;

  @override
  int get hashCode =>
      description.hashCode ^
      quantity.hashCode ^
      unitPrice.hashCode ^
      totalPrice.hashCode;

  @override
  String toString() =>
      'LineItem(description: $description, qty: $quantity, unitPrice: $unitPrice, total: $totalPrice)';
}

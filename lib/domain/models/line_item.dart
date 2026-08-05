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

  Map<String, dynamic> toJson() => {
        'description': description,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (totalPrice != null) 'total_price': totalPrice,
      };

  factory LineItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble();
    final unitP = (json['unit_price'] as num?)?.toDouble() ?? (json['unitPrice'] as num?)?.toDouble();
    final totalP = (json['total_price'] as num?)?.toDouble() ?? (json['totalPrice'] as num?)?.toDouble();
    return LineItem(
      description: (json['description'] as String?) ?? '',
      quantity: qty,
      unitPrice: unitP,
      totalPrice: totalP,
    );
  }

  /// Returns the base price for a single quantity.
  double get effectiveUnitPrice {
    if (unitPrice != null) return unitPrice!;
    if (totalPrice != null && quantity != null && quantity! > 0) {
      return totalPrice! / quantity!;
    }
    if (totalPrice != null) return totalPrice!;
    return 0.0;
  }

  /// Returns the total price for this line item (quantity * base price).
  double get lineTotal {
    final qty = (quantity != null && quantity! > 0) ? quantity! : 1.0;
    return effectiveUnitPrice * qty;
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

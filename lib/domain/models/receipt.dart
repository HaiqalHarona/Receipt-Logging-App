// lib/domain/models/receipt.dart

import 'package:flutter/foundation.dart';
import 'line_item.dart';

@immutable
class Receipt {
  final String id;
  final String merchant;
  final String date;
  final double amount;
  final String currency;
  final String category;
  final String? imagePath;

  /// Legacy flat string items retained for backward-compatibility.
  final List<String> items;

  /// Structured line items from the backend Vision AI extraction.
  /// Preferred over [items] when non-empty.
  final List<LineItem> lineItems;

  const Receipt({
    required this.id,
    required this.merchant,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    this.imagePath,
    this.items = const [],
    this.lineItems = const [],
  });

  Receipt copyWith({
    String? id,
    String? merchant,
    String? date,
    double? amount,
    String? currency,
    String? category,
    String? imagePath,
    List<String>? items,
    List<LineItem>? lineItems,
  }) {
    return Receipt(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      items: items ?? this.items,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'date': date,
      'amount': amount,
      'currency': currency,
      'category': category,
      'imagePath': imagePath,
      'items': items,
      'lineItems': lineItems.map((li) => li.toJson()).toList(),
    };
  }

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final parsedItems = (json['items'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    List<LineItem> parsedLineItems = [];
    if (json['lineItems'] is List) {
      parsedLineItems = (json['lineItems'] as List<dynamic>)
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['line_items'] is List) {
      parsedLineItems = (json['line_items'] as List<dynamic>)
          .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (parsedLineItems.isEmpty && parsedItems.isNotEmpty) {
      parsedLineItems = parseLegacyItemsToLineItems(parsedItems);
    }

    return Receipt(
      id: json['id'] as String? ?? 'receipt_${DateTime.now().millisecondsSinceEpoch}',
      merchant: json['merchant'] as String? ?? 'Unknown Merchant',
      date: json['date'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      category: json['category'] as String? ?? 'Other 📦',
      imagePath: json['imagePath'] as String?,
      items: parsedItems,
      lineItems: parsedLineItems,
    );
  }

  /// Parses legacy flat string items (e.g. "Organic Milk 1 Gal - $4.99") into [LineItem] domain objects.
  static List<LineItem> parseLegacyItemsToLineItems(List<String> rawItems) {
    return rawItems.map((raw) {
      String desc = raw.trim();
      double? price;

      // Match price pattern like "- $4.99" or "$4.99" or "4.99" at end of string
      final priceMatch = RegExp(r'[-–—]?\s*\$?\s*(\d+(?:\.\d{1,2})?)\s*$').firstMatch(desc);
      if (priceMatch != null) {
        price = double.tryParse(priceMatch.group(1) ?? '');
        desc = desc.substring(0, priceMatch.start).trim();
        // Remove trailing dash if present
        if (desc.endsWith('-') || desc.endsWith('–') || desc.endsWith('—')) {
          desc = desc.substring(0, desc.length - 1).trim();
        }
      }

      return LineItem(
        description: desc.isNotEmpty ? desc : raw,
        quantity: 1.0,
        unitPrice: price,
        totalPrice: price,
      );
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Receipt &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          merchant == other.merchant &&
          date == other.date &&
          amount == other.amount &&
          currency == other.currency &&
          category == other.category &&
          imagePath == other.imagePath &&
          listEquals(items, other.items) &&
          listEquals(lineItems, other.lineItems);

  @override
  int get hashCode =>
      id.hashCode ^
      merchant.hashCode ^
      date.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      category.hashCode ^
      imagePath.hashCode ^
      Object.hashAll(items) ^
      Object.hashAll(lineItems);

  @override
  String toString() {
    return 'Receipt(id: $id, merchant: $merchant, amount: $amount $currency, date: $date, lineItems: ${lineItems.length})';
  }
}

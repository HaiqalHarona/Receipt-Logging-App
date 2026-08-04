// lib/domain/models/receipt.dart

import 'package:flutter/foundation.dart';

@immutable
class Receipt {
  final String id;
  final String merchant;
  final String date;
  final double amount;
  final String currency;
  final String category;
  final String? imagePath;
  final List<String> items;

  const Receipt({
    required this.id,
    required this.merchant,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    this.imagePath,
    this.items = const [],
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
    };
  }

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String? ?? 'receipt_${DateTime.now().millisecondsSinceEpoch}',
      merchant: json['merchant'] as String? ?? 'Unknown Merchant',
      date: json['date'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      category: json['category'] as String? ?? 'Other 📦',
      imagePath: json['imagePath'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
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
          listEquals(items, other.items);

  @override
  int get hashCode =>
      id.hashCode ^
      merchant.hashCode ^
      date.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      category.hashCode ^
      imagePath.hashCode ^
      Object.hashAll(items);

  @override
  String toString() {
    return 'Receipt(id: $id, merchant: $merchant, amount: $amount $currency, date: $date)';
  }
}

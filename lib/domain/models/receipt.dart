// File: lib/domain/models/receipt.dart

import 'dart:convert';

/// Immutable Domain Model representing a parsed or saved receipt.
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

  static int _idCounter = 0;

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final defaultId = 'rcpt_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
    return Receipt(
      id: json['id']?.toString() ?? defaultId,
      merchant: json['merchant']?.toString() ?? 'Unknown Merchant',
      date: json['date']?.toString() ?? 'Aug 01, 2026',
      amount: _parseAmount(json['amount']),
      currency: json['currency']?.toString() ?? 'USD',
      category: json['category']?.toString() ?? 'General 🧾',
      imagePath: json['imagePath']?.toString(),
      items: (json['items'] is List)
          ? (json['items'] as List).map((e) => e.toString()).toList()
          : const [],
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
          category == other.category;

  @override
  int get hashCode =>
      id.hashCode ^
      merchant.hashCode ^
      date.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      category.hashCode;

  static double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  String toJsonString() => jsonEncode(toJson());

  factory Receipt.fromJsonString(String str) =>
      Receipt.fromJson(jsonDecode(str) as Map<String, dynamic>);
}

// File: lib/ui/core/utils/category_utils.dart

import 'package:flutter/material.dart';

/// Centralized Category Utilities for color coding, emoji stripping, and icon mapping.
class CategoryUtils {
  /// Strips emojis and trailing whitespace from a category string.
  static String sanitize(String cat) {
    if (cat.isEmpty) return 'General';
    final cleaned = cat
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]', unicode: true), '')
        .trim();
    return cleaned.isEmpty ? 'General' : cleaned;
  }

  /// Returns a unique theme accent color for each category.
  static Color getCategoryColor(String cat) {
    final clean = sanitize(cat).toLowerCase();
    if (clean.contains('grocer')) return const Color(0xFF10B981); // Emerald Green
    if (clean.contains('dining') || clean.contains('food')) return const Color(0xFFF59E0B); // Warm Amber
    if (clean.contains('transport') || clean.contains('fuel')) return const Color(0xFF3B82F6); // Electric Blue
    if (clean.contains('shop')) return const Color(0xFF8B5CF6); // Purple
    if (clean.contains('electron') || clean.contains('tech')) return const Color(0xFF06B6D4); // Cyan
    return const Color(0xFF64748B); // Slate Gray
  }

  /// Returns a clean Material icon for each category.
  static IconData getCategoryIcon(String cat) {
    final clean = sanitize(cat).toLowerCase();
    if (clean.contains('grocer')) return Icons.local_grocery_store_rounded;
    if (clean.contains('dining') || clean.contains('food')) return Icons.fastfood_rounded;
    if (clean.contains('transport') || clean.contains('fuel')) return Icons.directions_car_rounded;
    if (clean.contains('shop')) return Icons.shopping_bag_rounded;
    if (clean.contains('electron') || clean.contains('tech')) return Icons.devices_rounded;
    return Icons.receipt_long_rounded;
  }
}

import 'package:flutter/material.dart';

class AppColors {
  // Categories
  static const Map<String, Color> categoryColors = {
    'Food & Dining': Color(0xFFFF6B6B),
    'Shopping': Color(0xFF4ECDC4),
    'Transportation': Color(0xFF45B7D1),
    'Entertainment': Color(0xFFFFBE0B),
    'Healthcare': Color(0xFF96CEB4),
    'Utilities': Color(0xFF6C63FF),
    'Other': Color(0xFFA0AEC0),
  };

  static Color getCategoryColor(String? category) {
    return categoryColors[category] ?? categoryColors['Other']!;
  }

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9D97FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF82), Color(0xFF81C995)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

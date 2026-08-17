// File: lib/services/category_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cloud/models/user_models.dart';
import '../cloud/services/auth_service.dart';
import '../ui/core/utils/category_utils.dart';

/// Model representing a custom user-created category.
class CustomCategory {
  final String name;
  final int colorValue;
  final int iconCodePoint;

  const CustomCategory({
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
  });

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
      };

  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      name: (json['name'] as String?) ?? '',
      colorValue: (json['colorValue'] as int?) ??
          (json['color_value'] as int?) ??
          0xFF10B981,
      iconCodePoint: (json['iconCodePoint'] as int?) ??
          (json['icon_code_point'] as int?) ??
          0xe318,
    );
  }

  CustomCategoryDto toDto() => CustomCategoryDto(
        name: name,
        colorValue: colorValue,
        iconCodePoint: iconCodePoint,
      );

  factory CustomCategory.fromDto(CustomCategoryDto dto) => CustomCategory(
        name: dto.name,
        colorValue: dto.colorValue,
        iconCodePoint: dto.iconCodePoint,
      );
}

/// Service managing custom user-added categories persisted in SharedPreferences & Supabase.
/// Enforces a maximum limit of 8 custom categories.
class CategoryService extends ChangeNotifier {
  static final CategoryService instance = CategoryService._internal();
  CategoryService._internal();

  static const String _storageKey = 'custom_user_categories';
  static const int maxCustomCategories = 8;

  final List<CustomCategory> _customCategories = [];
  bool _isInitialized = false;

  List<CustomCategory> get customCategories =>
      List.unmodifiable(_customCategories);

  bool get isMaxReached => _customCategories.length >= maxCustomCategories;

  int get customCategoryCount => _customCategories.length;

  /// Initializes and loads custom categories from SharedPreferences.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawJson);
        _customCategories.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _customCategories.add(CustomCategory.fromJson(item));
          }
        }
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[CategoryService] Error loading custom categories: $e');
      _isInitialized = true;
    }
  }

  /// Syncs and overwrites local categories with cloud categories (Cloud Priority).
  Future<void> syncFromCloud(List<CustomCategory> cloudCategories) async {
    _customCategories.clear();
    _customCategories.addAll(cloudCategories);
    await _saveToDisk();
    _isInitialized = true;
    notifyListeners();
  }

  /// Adds a new custom category if limit is not reached and name is unique.
  Future<bool> addCategory(
      String name, int colorValue, int iconCodePoint) async {
    await init();
    final cleanName = CategoryUtils.sanitize(name).trim();
    if (cleanName.isEmpty) return false;
    if (isMaxReached) return false;

    // Avoid duplicate names (case-insensitive)
    final exists = _customCategories.any(
      (c) => c.name.toLowerCase() == cleanName.toLowerCase(),
    );
    if (exists) return false;

    final newCat = CustomCategory(
      name: cleanName,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );

    _customCategories.add(newCat);
    await _saveToDisk();
    notifyListeners();

    // Trigger cloud sync in background if logged in
    _syncToCloudIfLoggedIn();

    return true;
  }

  /// Removes a custom category by name.
  Future<bool> removeCategory(String name) async {
    await init();
    final clean = CategoryUtils.sanitize(name).toLowerCase();
    final beforeCount = _customCategories.length;
    _customCategories.removeWhere((c) => c.name.toLowerCase() == clean);
    if (_customCategories.length != beforeCount) {
      await _saveToDisk();
      notifyListeners();
      _syncToCloudIfLoggedIn();
      return true;
    }
    return false;
  }

  /// Clears all local custom categories (e.g. on logout/account reset).
  Future<void> clearAll() async {
    _customCategories.clear();
    await _saveToDisk();
    notifyListeners();
  }

  void _syncToCloudIfLoggedIn() {
    if (AuthService.instance.isLoggedIn) {
      final dtoList = _customCategories.map((c) => c.toDto()).toList();
      AuthService.instance.updateCustomCategories(dtoList);
    }
  }

  /// Finds a custom category by name if one exists.
  CustomCategory? findCustomCategory(String name) {
    final clean = CategoryUtils.sanitize(name).toLowerCase();
    for (final cat in _customCategories) {
      if (cat.name.toLowerCase() == clean) {
        return cat;
      }
    }
    return null;
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded =
          jsonEncode(_customCategories.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[CategoryService] Error saving custom categories: $e');
    }
  }
}

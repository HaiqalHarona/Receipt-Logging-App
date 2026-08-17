/// Dart DTO models for User endpoints.
///
/// Covers:
///   POST   /api/v1/user/create  → [UserRecordDto]
///   POST   /api/v1/user/login   → [UserLoginResponseDto]
///   GET    /api/v1/user/me      → [UserRecordDto]
///   PATCH  /api/v1/user/me      → [UserRecordDto]
///   DELETE /api/v1/user/me      → bool
library;

// ── CUSTOM CATEGORY DTO ──────────────────────────────────────────────────────

class CustomCategoryDto {
  const CustomCategoryDto({
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
  });

  final String name;
  final int colorValue;
  final int iconCodePoint;

  factory CustomCategoryDto.fromJson(Map<String, dynamic> json) {
    return CustomCategoryDto(
      name: (json['name'] as String?) ?? '',
      colorValue: (json['colorValue'] as int?) ??
          (json['color_value'] as int?) ??
          0xFF10B981,
      iconCodePoint: (json['iconCodePoint'] as int?) ??
          (json['icon_code_point'] as int?) ??
          0xe318,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
      };
}

// ── USER RECORD ───────────────────────────────────────────────────────────────

class UserRecordDto {
  const UserRecordDto({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    this.countryCode,
    this.mobileNumber,
    this.avatarImagePath,
    this.customCategories = const [],
    this.deletedAt,
  });

  final String id;
  final String username;
  final String email;
  final String? countryCode;
  final String? mobileNumber;
  final String? avatarImagePath;
  final List<CustomCategoryDto> customCategories;
  final String createdAt;
  final String? deletedAt;

  factory UserRecordDto.fromJson(Map<String, dynamic> json) {
    return UserRecordDto(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      countryCode: json['country_code'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      avatarImagePath: json['avatar_image_path'] as String?,
      customCategories: (json['custom_categories'] as List<dynamic>?)
              ?.map(
                  (e) => CustomCategoryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: (json['created_at'] as String?) ?? '',
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        if (countryCode != null) 'country_code': countryCode,
        if (mobileNumber != null) 'mobile_number': mobileNumber,
        if (avatarImagePath != null) 'avatar_image_path': avatarImagePath,
        'custom_categories': customCategories.map((c) => c.toJson()).toList(),
        'created_at': createdAt,
        if (deletedAt != null) 'deleted_at': deletedAt,
      };
}

// ── USER LOGIN RESPONSE ───────────────────────────────────────────────────────

class UserLoginResponseDto {
  const UserLoginResponseDto({
    required this.success,
    required this.message,
    this.user,
  });

  final bool success;
  final String message;
  final UserRecordDto? user;

  factory UserLoginResponseDto.fromJson(Map<String, dynamic> json) {
    return UserLoginResponseDto(
      success: (json['success'] as bool?) ?? false,
      message: (json['message'] as String?) ?? '',
      user: json['user'] != null
          ? UserRecordDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

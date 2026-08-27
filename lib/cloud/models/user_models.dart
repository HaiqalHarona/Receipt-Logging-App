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
    this.preferences = const {},
    this.emailVerifiedAt,
    this.mobileVerifiedAt,
    this.tier = 'free',
    this.deletedAt,
  });

  final String id;
  final String username;
  final String email;
  final String? countryCode;
  final String? mobileNumber;
  final String? avatarImagePath;
  final List<CustomCategoryDto> customCategories;
  final Map<String, dynamic> preferences;
  final String? emailVerifiedAt;
  final String? mobileVerifiedAt;
  final String tier;
  final String createdAt;
  final String? deletedAt;

  /// Whether the user's email address has been verified.
  bool get isEmailVerified =>
      emailVerifiedAt != null && emailVerifiedAt!.isNotEmpty;

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
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? const {},
      emailVerifiedAt: json['email_verified_at'] as String?,
      mobileVerifiedAt: json['mobile_verified_at'] as String?,
      tier: (json['tier'] as String?) ?? 'free',
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
        'preferences': preferences,
        if (emailVerifiedAt != null) 'email_verified_at': emailVerifiedAt,
        if (mobileVerifiedAt != null) 'mobile_verified_at': mobileVerifiedAt,
        'tier': tier,
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
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn,
  });

  final bool success;
  final String message;
  final UserRecordDto? user;
  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  factory UserLoginResponseDto.fromJson(Map<String, dynamic> json) {
    return UserLoginResponseDto(
      success: (json['success'] as bool?) ?? false,
      message: (json['message'] as String?) ?? '',
      user: json['user'] != null
          ? UserRecordDto.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: json['expires_in'] as int?,
    );
  }
}

/// Dart DTO models for User endpoints.
///
/// Covers:
///   POST   /api/v1/user/create  → [UserRecordDto]
///   POST   /api/v1/user/login   → [UserLoginResponseDto]
///   GET    /api/v1/user/me      → [UserRecordDto]
///   PATCH  /api/v1/user/me      → [UserRecordDto]
///   DELETE /api/v1/user/me      → bool
library;

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
    this.deletedAt,
  });

  final String id;
  final String username;
  final String email;
  final String? countryCode;
  final String? mobileNumber;
  final String? avatarImagePath;
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

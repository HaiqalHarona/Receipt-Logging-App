/// Dart DTO models for User endpoints.
///
/// Covers:
///   POST   /api/v1/user/create  → [UserRecordDto]
///   POST   /api/v1/user/login   → [UserLoginResponseDto]
///   GET    /api/v1/user/me      → [UserRecordDto]
///   DELETE /api/v1/user/me      → bool
library;

// ── USER RECORD ───────────────────────────────────────────────────────────────

class UserRecordDto {
  const UserRecordDto({
    required this.id,
    required this.username,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String username;
  final String createdAt;
  final String? deletedAt;

  factory UserRecordDto.fromJson(Map<String, dynamic> json) {
    return UserRecordDto(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
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

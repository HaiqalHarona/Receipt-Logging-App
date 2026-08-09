/// Dart DTO models for Device endpoints.
///
/// Covers:
///   POST /api/v1/devices/register  → [DeviceRecordDto]
///   GET  /api/v1/devices/me        → [DeviceRecordDto]
///   POST /api/v1/devices/link      → [DeviceRecordDto]
///   DELETE /api/v1/devices/me      → bool
library;

// ── DEVICE ────────────────────────────────────────────────────────────────────

class DeviceRecordDto {
  const DeviceRecordDto({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final String? userId;
  final String createdAt;

  factory DeviceRecordDto.fromJson(Map<String, dynamic> json) {
    return DeviceRecordDto(
      id: (json['id'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

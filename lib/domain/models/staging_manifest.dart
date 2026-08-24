// File: lib/domain/models/staging_manifest.dart

class StagingManifest {
  final String stage;
  final String channel;
  final String version;
  final int buildNumber;
  final String versionDisplay;
  final String downloadUrl;
  final String releaseNotes;
  final String? publishedAt;

  const StagingManifest({
    required this.stage,
    required this.channel,
    required this.version,
    required this.buildNumber,
    required this.versionDisplay,
    required this.downloadUrl,
    required this.releaseNotes,
    this.publishedAt,
  });

  factory StagingManifest.fromJson(Map<String, dynamic> json) {
    final ver = json['version'] as String? ?? '1.0.0';
    final bNum = json['buildNumber'] as int? ??
        int.tryParse('${json['buildNumber']}') ??
        1;
    return StagingManifest(
      stage: json['stage'] as String? ?? 'Alpha',
      channel: json['channel'] as String? ?? 'staging',
      version: ver,
      buildNumber: bNum,
      versionDisplay: json['versionDisplay'] as String? ??
          json['version_display'] as String? ??
          '$ver.0.$bNum',
      downloadUrl: json['downloadUrl'] as String? ??
          json['download_url'] as String? ??
          json['apkUrl'] as String? ??
          '',
      releaseNotes: json['releaseNotes'] as String? ??
          json['release_notes'] as String? ??
          'New staging build available.',
      publishedAt:
          json['publishedAt'] as String? ?? json['published_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'channel': channel,
      'version': version,
      'buildNumber': buildNumber,
      'versionDisplay': versionDisplay,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      if (publishedAt != null) 'publishedAt': publishedAt,
    };
  }

  /// Returns true if this remote manifest represents a newer version than the local build.
  bool isNewerThan(int currentBuildNumber) {
    return buildNumber > currentBuildNumber;
  }
}

// File: test/unit/staging_manifest_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:reciept_logging/domain/models/staging_manifest.dart';

void main() {
  group('StagingManifest Unit Tests', () {
    test('Correctly parses full JSON payload', () {
      final json = {
        'stage': 'Alpha',
        'channel': 'staging',
        'version': '1.0.1',
        'buildNumber': 12,
        'versionDisplay': '1.0.1.0.12',
        'downloadUrl': 'http://100.64.0.1:8085/builds/app.apk',
        'releaseNotes': 'Added Tailscale updates and performance boosts.',
        'publishedAt': '2026-08-24T20:30:00Z',
      };

      final manifest = StagingManifest.fromJson(json);

      expect(manifest.stage, 'Alpha');
      expect(manifest.channel, 'staging');
      expect(manifest.version, '1.0.1');
      expect(manifest.buildNumber, 12);
      expect(manifest.versionDisplay, '1.0.1.0.12');
      expect(manifest.downloadUrl, 'http://100.64.0.1:8085/builds/app.apk');
      expect(manifest.releaseNotes,
          'Added Tailscale updates and performance boosts.');
      expect(manifest.publishedAt, '2026-08-24T20:30:00Z');
    });

    test('isNewerThan correctly determines if remote build is higher', () {
      const manifest = StagingManifest(
        stage: 'Alpha',
        channel: 'staging',
        version: '1.0.1',
        buildNumber: 5,
        versionDisplay: '1.0.1.0.5',
        downloadUrl: 'http://example.com/app.apk',
        releaseNotes: 'Test build',
      );

      expect(manifest.isNewerThan(4), isTrue);
      expect(manifest.isNewerThan(5), isFalse);
      expect(manifest.isNewerThan(6), isFalse);
    });

    test('toJson produces expected structure', () {
      const manifest = StagingManifest(
        stage: 'Alpha',
        channel: 'staging',
        version: '1.0.1',
        buildNumber: 3,
        versionDisplay: '1.0.1.0.3',
        downloadUrl: 'http://example.com/app.apk',
        releaseNotes: 'Notes',
        publishedAt: '2026-08-24T00:00:00Z',
      );

      final json = manifest.toJson();

      expect(json['stage'], 'Alpha');
      expect(json['buildNumber'], 3);
      expect(json['versionDisplay'], '1.0.1.0.3');
      expect(json['publishedAt'], '2026-08-24T00:00:00Z');
    });
  });
}

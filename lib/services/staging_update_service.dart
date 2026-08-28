// File: lib/services/staging_update_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../cloud/api/api_config.dart';
import '../domain/models/staging_manifest.dart';
import '../ui/core/widgets/app_snack_bar.dart';
import '../ui/core/widgets/staging_update_dialog.dart';
import 'app_logger_service.dart';

/// Service responsible for Tailscale network reachability detection,
/// staging manifest polling, and in-app APK update downloads.
class StagingUpdateService extends ChangeNotifier {
  StagingUpdateService._();
  static final StagingUpdateService instance = StagingUpdateService._();

  bool _isChecking = false;
  bool _isTailscaleConnected = false;
  StagingManifest? _availableUpdate;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  bool get isChecking => _isChecking;
  bool get isTailscaleConnected => _isTailscaleConnected;
  StagingManifest? get availableUpdate => _availableUpdate;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  /// Probes the Tailscale staging server and device network interfaces to determine
  /// if the device is currently connected to the tailnet.
  Future<bool> probeTailscaleNetwork() async {
    // Strict production guard: never run staging probes in production
    if (!ApiConfig.isStaging || ApiConfig.isProduction) {
      _isTailscaleConnected = false;
      notifyListeners();
      return false;
    }

    final url = ApiConfig.stagingManifestUrl;

    // Strategy 1: Probe the staging manifest URL directly
    if (url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        final response =
            await http.get(uri).timeout(const Duration(milliseconds: 2500));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _isTailscaleConnected = true;
          AppLogger.info('StagingUpdateService',
              'Tailscale staging server reachable via manifest.');
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Continue to fallback strategies
      }
    }

    // Strategy 2: Probe the backend API health endpoint
    if (ApiConfig.baseUrl.isNotEmpty) {
      try {
        final healthUri = Uri.parse('${ApiConfig.baseUrl}/health');
        final response = await http
            .get(healthUri)
            .timeout(const Duration(milliseconds: 2000));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _isTailscaleConnected = true;
          AppLogger.info('StagingUpdateService',
              'Tailscale network reachable via backend API.');
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Continue to network interface check
      }
    }

    // Strategy 3: Check device network interfaces for Tailscale CGNAT IP (100.64.0.0/10)
    if (!kIsWeb) {
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );

        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (_isTailscaleCgnatIp(addr.address)) {
              _isTailscaleConnected = true;
              AppLogger.info('StagingUpdateService',
                  'Tailscale interface detected on device: ${addr.address}');
              notifyListeners();
              return true;
            }
          }
        }
      } catch (_) {
        // Network interface inspection failed or unsupported
      }
    }

    _isTailscaleConnected = false;
    notifyListeners();
    return false;
  }

  /// Validates if an IPv4 address falls within the Tailscale CGNAT range (100.64.0.0/10).
  static bool _isTailscaleCgnatIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    return first == 100 && second != null && second >= 64 && second <= 127;
  }

  /// Checks if a newer staging manifest is available from the Tailscale host.
  Future<StagingManifest?> checkStagingManifest() async {
    // Strict production guard: never check staging manifests in production
    if (!ApiConfig.isStaging || ApiConfig.isProduction) {
      _isTailscaleConnected = false;
      _availableUpdate = null;
      notifyListeners();
      return null;
    }

    if (_isChecking) return _availableUpdate;

    final url = ApiConfig.stagingManifestUrl;
    if (url.isEmpty) {
      _isTailscaleConnected = false;
      _availableUpdate = null;
      notifyListeners();
      return null;
    }

    _isChecking = true;
    notifyListeners();

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _isTailscaleConnected = true;
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final manifest = StagingManifest.fromJson(json);

        if (manifest.isNewerThan(ApiConfig.appBuildNumber)) {
          _availableUpdate = manifest;
          AppLogger.info(
            'StagingUpdateService',
            'New staging update found: ${manifest.versionDisplay} (Current: ${ApiConfig.appVersionDisplay})',
          );
        } else {
          _availableUpdate = null;
        }
      } else {
        _isTailscaleConnected = false;
        _availableUpdate = null;
      }
    } catch (e) {
      _isTailscaleConnected = false;
      _availableUpdate = null;
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return _availableUpdate;
  }

  /// Triggers an update check and optionally prompts the user with the update modal.
  Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateToast = false,
  }) async {
    final update = await checkStagingManifest();

    if (!context.mounted) return;

    if (update != null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StagingUpdateDialog(manifest: update),
      );
    } else if (showNoUpdateToast) {
      if (_isTailscaleConnected) {
        AppSnackBar.show(
          context,
          message:
              'You are on the latest ${ApiConfig.appEnv.toUpperCase()} build (${ApiConfig.appVersionDisplay}).',
        );
      } else {
        AppSnackBar.show(
          context,
          message:
              'Tailscale staging network unreachable. Make sure Tailscale is connected.',
          isError: true,
        );
      }
    }
  }

  /// Downloads the staging APK binary and opens the Android installer.
  Future<bool> downloadAndInstallApk(
    StagingManifest manifest, {
    void Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) return false;
    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(manifest.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      Directory? targetDir;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          targetDir = await getExternalStorageDirectory();
        } catch (_) {}
        if (targetDir == null || !await targetDir.exists()) {
          try {
            targetDir = await getDownloadsDirectory();
          } catch (_) {}
        }
      }
      targetDir ??= await getTemporaryDirectory();

      final fileName =
          'sancfund_${manifest.versionDisplay.replaceAll('.', '_')}.apk';
      final file = File('${targetDir.path}/$fileName');

      int bytesReceived = 0;
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        bytesReceived += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          _downloadProgress = (bytesReceived / contentLength).clamp(0.0, 1.0);
          onProgress?.call(_downloadProgress);
          notifyListeners();
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      AppLogger.info('StagingUpdateService',
          'APK downloaded successfully to: ${file.path}');

      // Launch native Android installer intent
      if (!kIsWeb && Platform.isAndroid) {
        final result = await OpenFilex.open(
          file.path,
          type: 'application/vnd.android.package-archive',
        );
        AppLogger.info(
            'StagingUpdateService', 'OpenFilex result: ${result.message}');
      }

      return true;
    } catch (e, st) {
      AppLogger.error(
          'StagingUpdateService', 'Failed to download or install APK', e, st);
      return false;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }
}

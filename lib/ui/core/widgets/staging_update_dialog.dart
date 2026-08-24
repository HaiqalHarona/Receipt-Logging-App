// File: lib/ui/core/widgets/staging_update_dialog.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../cloud/api/api_config.dart';
import '../../../domain/models/staging_manifest.dart';
import '../../../services/staging_update_service.dart';
import '../theme/theme_controller.dart';

class StagingUpdateDialog extends StatefulWidget {
  final StagingManifest manifest;

  const StagingUpdateDialog({
    super.key,
    required this.manifest,
  });

  @override
  State<StagingUpdateDialog> createState() => _StagingUpdateDialogState();
}

class _StagingUpdateDialogState extends State<StagingUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
    });

    final success = await StagingUpdateService.instance.downloadAndInstallApk(
      widget.manifest,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed. Check your Tailscale connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 8,
          intensity: 0.85,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          color: controller.currentBaseColor,
          border: NeumorphicBorder(
            color: accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Badge ──
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(
                          0xFF10B981), // Emerald green Tailscale indicator
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TAILSCALE STAGING · ${widget.manifest.stage.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Title & Version ──
              Text(
                'New Version Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'v${widget.manifest.versionDisplay}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(Current: v${ApiConfig.appVersionDisplay})',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Release Notes Box ──
              Neumorphic(
                style: NeumorphicStyle(
                  depth: -2.5,
                  intensity: 0.8,
                  boxShape:
                      NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                  color: controller.currentBaseColor,
                ),
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.manifest.releaseNotes,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),

              if (_isDownloading) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: textSecondary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _progress > 0
                        ? '${(_progress * 100).toInt()}% Downloading APK...'
                        : 'Connecting to Tailscale host...',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Action Buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isDownloading)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isDownloading ? null : _startDownload,
                    child: Neumorphic(
                      style: NeumorphicStyle(
                        depth: _isDownloading ? -1 : 3,
                        intensity: 0.9,
                        color: accent,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(10)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDownloading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.download_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _isDownloading ? 'Downloading' : 'Update & Install',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

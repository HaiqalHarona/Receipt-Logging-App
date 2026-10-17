import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../services/local_image_cache_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Reusable Neumorphic user avatar widget.
///
/// Features:
/// 1. Synchronously reads the cached avatar file and in-memory bytes from [LocalImageCacheService]
///    on Frame 1, eliminating FutureBuilder flash, delay, and initial-frame placeholder pop-in.
/// 2. Uses raw in-memory byte buffers via [Image.memory] to guarantee immediate visual updates
///    across all mounted pages and background tabs without stale path-based cache collisions.
/// 3. Automatically updates when [LocalImageCacheService] notifies of eager loads or avatar changes.
/// 4. Renders a tactile Neumorphic circular button with smooth press animation if [onTap] is provided,
///    or a clean static Neumorphic container if non-interactive.
/// 5. Gracefully renders stylized fallback user initials with theme accent colors when no avatar is set.
class NeumorphicUserAvatar extends StatelessWidget {
  final String size;
  final double diameter;
  final String username;
  final Color? accentColor;
  final Color? fallbackColor;
  final VoidCallback? onTap;
  final double depth;
  final bool standalone;

  const NeumorphicUserAvatar({
    super.key,
    this.size = 'medium',
    this.diameter = 50.0,
    required this.username,
    this.accentColor,
    this.fallbackColor,
    this.onTap,
    this.depth = 4.0,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final controller = AppThemeController.instance;
    final base = controller.currentBaseColor;

    return ListenableBuilder(
      listenable: LocalImageCacheService.instance,
      builder: (context, _) {
        final cache = LocalImageCacheService.instance;
        final cachedBytes = cache.getCachedAvatarBytes(size);
        final cachedFile = cache.getCachedAvatar(size);
        final rev = cache.avatarRevision;

        Widget avatarContent;
        if (cachedBytes != null && cachedBytes.isNotEmpty) {
          avatarContent = Image.memory(
            cachedBytes,
            key: ValueKey('avatar_mem_${size}_$rev'),
            fit: BoxFit.cover,
            width: diameter,
            height: diameter,
            errorBuilder: (_, __, ___) => _buildFallback(username, accent),
          );
        } else if (cachedFile != null && cachedFile.existsSync()) {
          avatarContent = Image.file(
            cachedFile,
            key: ValueKey('avatar_file_${cachedFile.path}_$rev'),
            fit: BoxFit.cover,
            width: diameter,
            height: diameter,
            errorBuilder: (_, __, ___) => _buildFallback(username, accent),
          );
        } else {
          avatarContent = _buildFallback(username, accent);
        }

        final innerClip = ClipOval(
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: avatarContent,
          ),
        );

        if (standalone || onTap != null) {
          if (onTap != null) {
            return NeumorphicTactileButton(
              onPressed: onTap,
              depth: depth,
              pressedDepth: 0.0,
              pressedScale: 0.96,
              boxShape: const NeumorphicBoxShape.circle(),
              padding: EdgeInsets.zero,
              color: base,
              border: NeumorphicBorder(
                color: accent.withValues(alpha: 0.8),
                width: 1.5,
              ),
              child: innerClip,
            );
          }

          return Neumorphic(
            style: NeumorphicStyle(
              shape: NeumorphicShape.flat,
              boxShape: const NeumorphicBoxShape.circle(),
              depth: depth,
              color: base,
              border: NeumorphicBorder(
                color: accent.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: innerClip,
          );
        }

        return innerClip;
      },
    );
  }

  Widget _buildFallback(String username, Color accent) {
    final clean = username.trim();
    final initial = clean.isNotEmpty ? clean[0].toUpperCase() : '';
    if (initial.isNotEmpty) {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: diameter * 0.4,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person_rounded,
        color: accent,
        size: diameter * 0.52,
      ),
    );
  }
}

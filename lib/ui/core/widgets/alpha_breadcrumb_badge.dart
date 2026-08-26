// File: lib/ui/core/widgets/alpha_breadcrumb_badge.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../cloud/api/api_config.dart';
import '../../../services/staging_update_service.dart';
import '../theme/theme_controller.dart';

class AlphaBreadcrumbBadge extends StatefulWidget {
  final bool compact;

  const AlphaBreadcrumbBadge({
    super.key,
    this.compact = false,
  });

  @override
  State<AlphaBreadcrumbBadge> createState() => _AlphaBreadcrumbBadgeState();
}

class _AlphaBreadcrumbBadgeState extends State<AlphaBreadcrumbBadge> {
  @override
  void initState() {
    super.initState();
    // Probe Tailscale network on badge initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StagingUpdateService.instance.probeTailscaleNetwork();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.isStaging || ApiConfig.isProduction) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        StagingUpdateService.instance,
      ]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final isTailscale = StagingUpdateService.instance.isTailscaleConnected;
        final isChecking = StagingUpdateService.instance.isChecking;

        return GestureDetector(
          onTap: () {
            StagingUpdateService.instance.checkForUpdates(
              context,
              showNoUpdateToast: true,
            );
          },
          child: Neumorphic(
            style: NeumorphicStyle(
              depth: 2,
              intensity: 0.8,
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
              color: controller.currentBaseColor,
              border: isTailscale
                  ? NeumorphicBorder(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1.0,
                    )
                  : NeumorphicBorder(
                      color: textSecondary.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isTailscale
                        ? const Color(0xFF10B981) // Tailscale green
                        : (isChecking
                            ? accent
                            : textSecondary.withValues(alpha: 0.4)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${ApiConfig.appEnv.toUpperCase()} v${ApiConfig.appVersionDisplay}',
                  style: TextStyle(
                    fontSize: widget.compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isTailscale
                        ? textSecondary
                        : textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                if (isTailscale) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sync_rounded,
                    size: 12,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

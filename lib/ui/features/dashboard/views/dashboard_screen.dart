import 'dart:io';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/local_image_cache_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../view_models/dashboard_view_model.dart';
import 'widgets/monthly_spending_graph_card.dart';
import 'widgets/recent_transactions_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final DashboardViewModel _viewModel = DashboardViewModel();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([AppThemeController.instance, _viewModel]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 16, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _viewModel.isLoggedIn &&
                                        _viewModel.username != null &&
                                        _viewModel.username!.isNotEmpty
                                    ? "Welcome back, ${_viewModel.username}."
                                    : "Welcome back",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Here is your spending breakdown",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_viewModel.isLoggedIn)
                          GestureDetector(
                            onTap: () => context.push('/user-settings'),
                            child: _buildAvatarWidget(
                                _viewModel.avatarImagePath,
                                accent,
                                textSecondary,
                                controller),
                          )
                        else
                          GestureDetector(
                            onTap: () => context.push('/auth'),
                            child: Neumorphic(
                              style: NeumorphicStyle(
                                depth: 4,
                                intensity: 0.85,
                                boxShape: const NeumorphicBoxShape.circle(),
                                color: controller.currentBaseColor,
                                border: NeumorphicBorder(
                                  color: controller.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.white.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: Center(
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Monthly Spending Line Graph (encompasses indented summary carousel)
                    MonthlySpendingGraphCard(
                      viewModel: _viewModel,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      accent: accent,
                    ),
                    const SizedBox(height: 28),

                    // Recent Receipts Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Receipts",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/history'),
                          child: Text(
                            "See All",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Recent Receipts List
                    RecentTransactionsList(
                      viewModel: _viewModel,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      accent: accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarWidget(
    String? path,
    Color accent,
    Color fallbackColor,
    AppThemeController controller,
  ) {
    final isDark = controller.isDarkMode;
    final base = controller.currentBaseColor;

    return Neumorphic(
      style: NeumorphicStyle(
        depth: 4,
        intensity: 0.85,
        boxShape: const NeumorphicBoxShape.circle(),
        color: base,
        border: NeumorphicBorder(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: SizedBox(
        width: 38,
        height: 38,
        child: ClipOval(
          child: _buildAvatarImage(path, accent, fallbackColor),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String? path, Color accent, Color fallbackColor) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: 38,
          height: 38,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person_rounded, color: accent, size: 22),
        );
      } else if (File(path).existsSync()) {
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: 38,
          height: 38,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person_rounded, color: accent, size: 22),
        );
      } else {
        // Fetch securely from local session image cache or authenticated backend streaming
        return FutureBuilder<File?>(
          future: LocalImageCacheService.instance.getOrFetchAvatar(size: 'small'),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.file(
                snapshot.data!,
                fit: BoxFit.cover,
                width: 38,
                height: 38,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_rounded, color: accent, size: 22),
              );
            }
            return Icon(Icons.person_rounded, color: accent, size: 22);
          },
        );
      }
    }
    return Icon(Icons.person_rounded, color: accent, size: 22);
  }
}

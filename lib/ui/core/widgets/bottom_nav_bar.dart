import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppBottomNavBar extends StatelessWidget {
  final String currentPath;

  const AppBottomNavBar({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final activeColor = isDark ? AppTheme.darkAccentPinkishRed : AppTheme.lightAccentTeal;
    final inactiveColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final navBg = isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground;

    return Neumorphic(
      style: NeumorphicStyle(
        depth: 4,
        intensity: 0.5,
        boxShape: NeumorphicBoxShape.rect(),

        color: navBg,
      ),

      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context: context,
              icon: Icons.home_rounded,
              label: 'Home',
              path: '/dashboard',
              isActive: currentPath == '/dashboard',
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
            _buildNavItem(
              context: context,
              icon: Icons.receipt_long_rounded,
              label: 'History',
              path: '/history',
              isActive: currentPath == '/history',
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
            _buildNavItem(
              context: context,
              icon: Icons.smart_toy_rounded, // Bot Icon for AI Chat
              label: 'AI Chat',
              path: '/ai-assistant',
              isActive: currentPath == '/ai-assistant',
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              path: '/settings',
              isActive: currentPath == '/settings',
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String path,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.go(path);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

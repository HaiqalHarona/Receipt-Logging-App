// File: lib/ui/core/router/main_tab_shell.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../theme/theme_controller.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/history/views/history_screen.dart';
import '../../features/ai_assistant/views/ai_assistant_screen.dart';
import '../../features/settings/views/settings_screen.dart';

/// Persistent shell container hosting primary tabs inside a high-FPS [IndexedStack]
/// with subtle lightweight micro-fade transitions and stationary [AppBottomNavBar].
class MainTabShell extends StatefulWidget {
  final String currentPath;

  const MainTabShell({
    super.key,
    required this.currentPath,
  });

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  static const List<String> _paths = [
    '/dashboard',
    '/history',
    '/ai-assistant',
    '/settings',
  ];

  int _currentIndex = 0;

  int _indexForPath(String path) {
    if (path.startsWith('/history')) return 1;
    if (path.startsWith('/ai-assistant')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0; // Default to /dashboard
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForPath(widget.currentPath);
  }

  @override
  void didUpdateWidget(covariant MainTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetIndex = _indexForPath(widget.currentPath);
    if (targetIndex != _currentIndex) {
      setState(() {
        _currentIndex = targetIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: IndexedStack(
              index: _currentIndex,
              children: [
                _TabContentWrapper(
                  isActive: _currentIndex == 0,
                  child: const DashboardScreen(),
                ),
                _TabContentWrapper(
                  isActive: _currentIndex == 1,
                  child: const HistoryScreen(),
                ),
                _TabContentWrapper(
                  isActive: _currentIndex == 2,
                  child: const AiAssistantScreen(),
                ),
                _TabContentWrapper(
                  isActive: _currentIndex == 3,
                  child: const SettingsScreen(),
                ),
              ],
            ),
            bottomNavigationBar: AppBottomNavBar(
              currentPath: _paths[_currentIndex],
            ),
          ),
        );
      },
    );
  }
}

class _TabContentWrapper extends StatelessWidget {
  final bool isActive;
  final Widget child;

  const _TabContentWrapper({
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: RepaintBoundary(child: child),
    );
  }
}


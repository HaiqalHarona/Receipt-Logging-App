// File: lib/ui/core/router/main_tab_shell.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_controller.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/history/views/history_screen.dart';
import '../../features/ai_assistant/views/ai_assistant_screen.dart';
import '../../features/settings/views/settings_screen.dart';

/// Persistent shell container hosting primary tabs inside a horizontal [PageView]
/// with a stationary pinned [AppBottomNavBar].
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

  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isAnimatingPage = false;

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
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant MainTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetIndex = _indexForPath(widget.currentPath);
    if (targetIndex != _currentIndex) {
      _currentIndex = targetIndex;
      if (_pageController.hasClients && !_isAnimatingPage) {
        _pageController.jumpToPage(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _isAnimatingPage = true;
      context.go(_paths[index]);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isAnimatingPage = false;
        }
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
            body: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              // TEMPORARILY DISABLED: Horizontal swiping gesture disabled for now.
              // Re-enable by changing physics back to: const BouncingScrollPhysics()
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                RepaintBoundary(child: DashboardScreen()),
                RepaintBoundary(child: HistoryScreen()),
                RepaintBoundary(child: AiAssistantScreen()),
                RepaintBoundary(child: SettingsScreen()),
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

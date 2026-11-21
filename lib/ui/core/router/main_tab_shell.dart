// File: lib/ui/core/router/main_tab_shell.dart

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_gradient_background.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/coach_mark_overlay.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/history/views/history_screen.dart';
import '../../features/ai_assistant/views/ai_assistant_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../../services/staging_update_service.dart';
import '../../../services/tutorial_service.dart';
import '../../../services/onboarding_service.dart';

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
  bool _isNavVisible = true;
  final GlobalKey _fabKey = GlobalKey();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StagingUpdateService.instance.checkForUpdates(context);
      if (OnboardingService.instance.hasCompletedOnboarding &&
          !TutorialService.instance.hasDismissedTutorial &&
          TutorialService.instance.currentStep == 0) {
        TutorialService.instance.startTutorial();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MainTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetIndex = _indexForPath(widget.currentPath);
    if (targetIndex != _currentIndex) {
      setState(() {
        _currentIndex = targetIndex;
        _isNavVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppThemeController.instance,
        TutorialService.instance,
      ]),
      builder: (context, _) {
        final isTutorialStep1 =
            _currentIndex == 0 && TutorialService.instance.currentStep == 1;

        return AppGradientBackground(
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                body: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }

                    // Enforce nav bar visibility when step 1 tutorial is active
                    if (isTutorialStep1) {
                      if (!_isNavVisible) {
                        setState(() {
                          _isNavVisible = true;
                        });
                      }
                      return false;
                    }

                    // Auto-reveal when user reaches the top of the scrollable page
                    if (notification.metrics.pixels <= 0) {
                      if (!_isNavVisible) {
                        setState(() {
                          _isNavVisible = true;
                        });
                      }
                      return false;
                    }

                    // React only to medium‑speed scroll updates (4.0‑12.0)
                    if (notification is ScrollUpdateNotification) {
                      final delta = notification.scrollDelta ?? 0.0;
                      final speed = delta.abs();
                      if (speed >= 4.0 && speed <= 12.0) {
                        if (delta > 0 && _isNavVisible) {
                          // downward scroll – hide
                          setState(() => _isNavVisible = false);
                        } else if (delta < 0 && !_isNavVisible) {
                          // upward scroll – show
                          setState(() => _isNavVisible = true);
                        }
                      }
                    }

                    return false;
                  },
                  child: IndexedStack(
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
                ),
                bottomNavigationBar: AnimatedSlide(
                  offset: _isNavVisible ? Offset.zero : const Offset(0, 1.45),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: AnimatedOpacity(
                    opacity: _isNavVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: !_isNavVisible,
                      child: AppBottomNavBar(
                        currentPath: _paths[_currentIndex],
                        fabKey: _fabKey,
                      ),
                    ),
                  ),
                ),
              ),

              // Step 1 Tutorial Coach Mark Overlay pointing at Scan FAB
              if (isTutorialStep1)
                CoachMarkOverlay(
                  targetKey: _fabKey,
                  isCircle: true,
                  holePadding: 4.0,
                  stepIndicator: 'Step 1 of 3: Scan',
                  title: TutorialService.instance.scanErrorMessage != null
                      ? 'Try Scanning Again'
                      : 'Scan Your First Receipt',
                  subtitle: TutorialService.instance.scanErrorMessage != null
                      ? 'Tap the camera button below to try scanning your receipt again.'
                      : 'Tap the camera button below to scan a new receipt.',
                  errorMessage: TutorialService.instance.scanErrorMessage,
                  onSkip: () => TutorialService.instance.dismissTutorial(),
                  onTargetTap: () {
                    TutorialService.instance.advanceStep();
                    context.push('/scanner');
                  },
                ),
            ],
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

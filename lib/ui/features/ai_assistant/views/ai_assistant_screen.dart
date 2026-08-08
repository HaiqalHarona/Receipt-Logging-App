import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: AppThemeController.instance,
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
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 105),
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row with icon
                          Row(
                            children: [
                              Text(
                                "AI Assistant",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const Spacer(),
                              NeumorphicIconBadge(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: accent,
                                iconSize: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Animated AI Greeting Bubble
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 280),
                                  child: NeumorphicCardWidget(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // AI Avatar dot
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 4, right: 8),
                                          decoration: BoxDecoration(
                                            color: accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            "Hi! How can I assist you with your spending today?",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: textPrimary,
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // User Message Bubble — accent-colored pill
                          Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Neumorphic(
                                style: NeumorphicStyle(
                                  depth: 5,
                                  intensity: 0.9,
                                  color: accent,
                                  boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(18),
                                  ),
                                  border: NeumorphicBorder(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Text(
                                    "How much did I spend on groceries this month?",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // AI Response Bubble
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: NeumorphicCardWidget(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4, right: 8),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "You spent \$248.50 across 6 grocery receipts this month.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textPrimary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Chat Input Bar
                          NeumorphicInputFieldWidget(
                            borderRadius: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Ask about your spending...",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                                Neumorphic(
                                  style: NeumorphicStyle(
                                    depth: 4,
                                    intensity: 0.85,
                                    color: accent,
                                    boxShape: const NeumorphicBoxShape.circle(),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
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
}

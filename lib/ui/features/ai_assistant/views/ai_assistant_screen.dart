import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AI Assistant 🤖",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // User Message Bubble
                      Align(
                        alignment: Alignment.centerRight,
                        child: Neumorphic(
                          style: NeumorphicStyle(
                            depth: 4,
                            color: AppTheme.darkAccentPinkishRed,
                            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              "How much did I spend on groceries this month?",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Response Bubble
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Neumorphic(
                          style: NeumorphicStyle(
                            depth: 4,
                            color: AppTheme.darkCardBackground,
                            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "You spent \$248.50 across 6 grocery receipts this month.",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Chat Input Bar
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -3,
                          intensity: 0.6,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(24)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Ask about your spending...",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                ),
                              ),
                              Icon(Icons.send_rounded, color: AppTheme.darkAccentPinkishRed, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppBottomNavBar(currentPath: '/ai-assistant'),
            ],
          ),
        ),
      ),
    );
  }
}

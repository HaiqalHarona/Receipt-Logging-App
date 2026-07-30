import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final accent = isDark ? AppTheme.darkAccentPinkishRed : AppTheme.lightAccentTeal;

    return NeumorphicBackground(
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
                      Text(
                        "AI Assistant 🤖",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // User Message Bubble
                      Align(
                        alignment: Alignment.centerRight,
                        child: NeumorphicButtonWidget(
                          color: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: const Text(
                            "How much did I spend on groceries this month?",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Response Bubble
                      Align(
                        alignment: Alignment.centerLeft,
                        child: NeumorphicCardWidget(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "You spent \$248.50 across 6 grocery receipts this month.",
                            style: TextStyle(
                              fontSize: 13,
                              color: textPrimary,
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
                            Icon(Icons.send_rounded, color: accent, size: 20),
                          ],
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


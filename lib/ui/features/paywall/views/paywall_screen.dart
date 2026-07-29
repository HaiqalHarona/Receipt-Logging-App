import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      "⚡ Unlimited Vision AI Receipt Parsing",
      "☁️ Automatic Cloud Sync & Offsite Backup",
      "📊 Advanced Analytics & CSV Export",
      "🤖 Priority AI Assistant Queries",
    ];

    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppTheme.darkTextSecondary),
              onPressed: () => context.pop(),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const Center(
                  child: Text(
                    "👑 PRO MEMBERSHIP",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkAccentPinkishRed,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "Unlock Unlimited AI Scans",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Features List
                Column(
                  children: features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 3,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.darkTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Plan Selector Card
                Neumorphic(
                  style: NeumorphicStyle(
                    depth: 4,
                    color: AppTheme.darkCardBackground,
                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ANNUAL PLAN — \$39.99/yr",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkAccentPinkishRed,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Save 33% • Just \$3.33/month",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Trial CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButton(
                    onPressed: () {
                      context.pop();
                    },
                    style: NeumorphicStyle(
                      color: AppTheme.darkAccentPinkishRed,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                    ),
                    child: const Center(
                      child: Text(
                        "Start 7-Day Free Trial",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

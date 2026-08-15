import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = NeumorphicTheme.isUsingDark(context);
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final accent =
        isDark ? AppTheme.darkAccentPinkishRed : AppTheme.lightAccentTeal;

    final features = [
      (icon: Icons.bolt_rounded, title: "Unlimited Vision AI Receipt Parsing"),
      (
        icon: Icons.cloud_done_rounded,
        title: "Automatic Cloud Sync & Offsite Backup"
      ),
      (icon: Icons.bar_chart_rounded, title: "Advanced Analytics & CSV Export"),
      (
        icon: Icons.auto_awesome_rounded,
        title: "Priority AI Assistant Queries"
      ),
    ];

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: NeumorphicIconBadge(
                icon: Icons.close_rounded,
                iconSize: 18,
                onTap: () => context.pop(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Center(
                  child: Text(
                    "PRO MEMBERSHIP",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Unlock Unlimited AI Scans",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Features List
                Column(
                  children: features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NeumorphicCardWidget(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              feature.icon,
                              color: accent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Plan Selector Card
                NeumorphicCardWidget(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ANNUAL PLAN — \$39.99/yr",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Save 33% • Just \$3.33/month",
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Trial CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: NeumorphicButtonWidget(
                    onPressed: () {
                      context.pop();
                    },
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

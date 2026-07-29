import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = [
      {"label": "Dark Mode Theme", "val": "Enabled"},
      {"label": "Currency", "val": "USD (\$)"},
      {"label": "Vision AI Backend URL", "val": "https://api.receipts.app"},
      {"label": "Export Database (JSON/CSV)", "val": "Export"},
    ];

    return NeumorphicBackground(
      backendColor: AppTheme.darkBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // User Profile Card
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: 4,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Neumorphic(
                                style: const NeumorphicStyle(
                                  boxShape: NeumorphicBoxShape.circle(),
                                  depth: 3,
                                  color: AppTheme.darkAccentPinkishRed,
                                ),
                                child: const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.darkAccentPinkishRed,
                                  child: Icon(Icons.person, color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      "Nino",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkTextPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "👑 Pro Member",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkAccentPinkishRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.star_rounded, color: AppTheme.darkAccentPinkishRed),
                                onPressed: () {
                                  context.push('/paywall');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Settings Options List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: settings.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = settings[index];
                          return Neumorphic(
                            style: NeumorphicStyle(
                              depth: 3,
                              color: AppTheme.darkCardBackground,
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item["label"]!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.darkTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    item["val"]!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkAccentPinkishRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const AppBottomNavBar(currentPath: '/settings'),
            ],
          ),
        ),
      ),
    );
  }
}

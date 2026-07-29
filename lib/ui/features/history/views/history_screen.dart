import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyItems = [
      {"name": "Target Superstore", "date": "Jul 29", "cat": "Shopping", "price": "-\$84.20", "icon": Icons.shopping_cart_rounded},
      {"name": "Shell Gas Station", "date": "Jul 27", "cat": "Transport", "price": "-\$45.00", "icon": Icons.local_gas_station_rounded},
      {"name": "Uber Eats", "date": "Jul 25", "cat": "Dining", "price": "-\$28.50", "icon": Icons.fastfood_rounded},
      {"name": "Apple Store", "date": "Jul 20", "cat": "Electronics", "price": "-\$129.00", "icon": Icons.phone_iphone_rounded},
      {"name": "Trader Joe's", "date": "Jul 18", "cat": "Groceries", "price": "-\$56.40", "icon": Icons.store_rounded},
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
                        "Receipt History",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -3,
                          intensity: 0.6,
                          color: AppTheme.darkCardBackground,
                          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: AppTheme.darkTextSecondary, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "Search merchant or item...",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: historyItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = historyItems[index];
                          return Neumorphic(
                            style: NeumorphicStyle(
                              depth: 3,
                              intensity: 0.5,
                              color: AppTheme.darkCardBackground,
                              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Neumorphic(
                                    style: const NeumorphicStyle(
                                      depth: -2,
                                      boxShape: NeumorphicBoxShape.circle(),
                                      color: AppTheme.darkBackground,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        item["icon"] as IconData,
                                        color: AppTheme.darkAccentPinkishRed,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item["name"] as String,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${item["cat"]} • ${item["date"]}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    item["price"] as String,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkTextPrimary,
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
              const AppBottomNavBar(currentPath: '/history'),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;

    final historyItems = [
      {"name": "Target Superstore", "date": "Jul 29", "cat": "Shopping", "price": "-\$84.20", "icon": Icons.shopping_cart_rounded},
      {"name": "Shell Gas Station", "date": "Jul 27", "cat": "Transport", "price": "-\$45.00", "icon": Icons.local_gas_station_rounded},
      {"name": "Uber Eats", "date": "Jul 25", "cat": "Dining", "price": "-\$28.50", "icon": Icons.fastfood_rounded},
      {"name": "Apple Store", "date": "Jul 20", "cat": "Electronics", "price": "-\$129.00", "icon": Icons.phone_iphone_rounded},
      {"name": "Trader Joe's", "date": "Jul 18", "cat": "Groceries", "price": "-\$56.40", "icon": Icons.store_rounded},
    ];

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppBottomNavBar(currentPath: '/history'),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Receipt History",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      NeumorphicInputFieldWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              "Search merchant or item...",
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
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
                          return NeumorphicCardWidget(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                NeumorphicIconBadge(
                                  icon: item["icon"] as IconData,
                                  isInset: true,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["name"] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${item["cat"]} • ${item["date"]}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  item["price"] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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


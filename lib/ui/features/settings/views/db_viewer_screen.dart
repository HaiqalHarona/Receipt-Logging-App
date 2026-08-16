// File: lib/ui/features/settings/views/db_viewer_screen.dart

import 'dart:convert';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/isar_service.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../data/seeders/receipt_seeder.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snack_bar.dart';

class DbViewerScreen extends StatefulWidget {
  const DbViewerScreen({super.key});

  @override
  State<DbViewerScreen> createState() => _DbViewerScreenState();
}

class _DbViewerScreenState extends State<DbViewerScreen> {
  String? _selectedReceiptJson;

  @override
  void initState() {
    super.initState();
    ReceiptRepository.instance.addListener(_onDbChanged);
  }

  @override
  void dispose() {
    ReceiptRepository.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;
    final accent = controller.accentColor;
    final receipts = ReceiptRepository.instance.receipts;
    final dbPath = IsarService.isar.path;

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    NeumorphicButton(
                      style: NeumorphicStyle(
                        depth: 3,
                        intensity: 0.8,
                        boxShape: const NeumorphicBoxShape.circle(),
                        color: NeumorphicTheme.baseColor(context),
                      ),
                      padding: const EdgeInsets.all(10),
                      onPressed: () => context.pop(),
                      child: Icon(Icons.arrow_back_rounded,
                          color: textPrimary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Isar DB Viewer",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    NeumorphicButton(
                      style: NeumorphicStyle(
                        depth: 3,
                        intensity: 0.8,
                        boxShape: const NeumorphicBoxShape.circle(),
                        color: NeumorphicTheme.baseColor(context),
                      ),
                      padding: const EdgeInsets.all(10),
                      onPressed: () => ReceiptRepository.instance.init(),
                      child:
                          Icon(Icons.refresh_rounded, color: accent, size: 20),
                    ),
                  ],
                ),
              ),

              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Storage Info Card
                      Neumorphic(
                        style: NeumorphicStyle(
                          depth: -2,
                          intensity: 0.7,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(16)),
                          color: NeumorphicTheme.baseColor(context),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storage_rounded,
                                    color: accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Isar Storage Info",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${receipts.length} records",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Database Path:",
                              style:
                                  TextStyle(fontSize: 11, color: textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dbPath ?? 'Unknown path',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Web Inspector:",
                              style:
                                  TextStyle(fontSize: 11, color: textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "https://inspect.isar.dev (adb forward tcp:9000 tcp:9000)",
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Stored Receipts (${receipts.length})",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              NeumorphicButton(
                                style: NeumorphicStyle(
                                  depth: 2,
                                  boxShape: NeumorphicBoxShape.roundRect(
                                      BorderRadius.circular(8)),
                                  color: accent.withValues(alpha: 0.15),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                onPressed: () async {
                                  await ReceiptSeeder.seedDatabase();
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      message:
                                          'Seeded 24 receipts across 12 months!',
                                    );
                                  }
                                },
                                child: Text(
                                  "Seed DB (24)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accent,
                                  ),
                                ),
                              ),
                              if (receipts.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                NeumorphicButton(
                                  style: NeumorphicStyle(
                                    depth: 2,
                                    boxShape: NeumorphicBoxShape.roundRect(
                                        BorderRadius.circular(8)),
                                    color:
                                        Colors.redAccent.withValues(alpha: 0.1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  onPressed: () {
                                    _showClearConfirmDialog(context);
                                  },
                                  child: Text(
                                    "Clear DB",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (receipts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              "Isar database is empty.\nScan or add receipts to view them here.",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: receipts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final r = receipts[index];
                            final isExpanded = _selectedReceiptJson == r.id;

                            return Neumorphic(
                              style: NeumorphicStyle(
                                depth: 2,
                                boxShape: NeumorphicBoxShape.roundRect(
                                    BorderRadius.circular(14)),
                                color: NeumorphicTheme.baseColor(context),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.merchant,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${r.currency} ${r.amount.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        r.date,
                                        style: TextStyle(
                                            fontSize: 12, color: textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "•",
                                        style: TextStyle(
                                            fontSize: 12, color: textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        r.category,
                                        style: TextStyle(
                                            fontSize: 12, color: textSecondary),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedReceiptJson =
                                                isExpanded ? null : r.id;
                                          });
                                        },
                                        child: Text(
                                          isExpanded
                                              ? "Hide JSON"
                                              : "View JSON",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        const JsonEncoder.withIndent('  ')
                                            .convert(r.toJson()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Isar Database?"),
        content: const Text(
          "This will delete all stored receipt records from the local Isar database. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ReceiptRepository.instance.clearAll();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

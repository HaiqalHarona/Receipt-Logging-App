// File: lib/ui/features/receipt_detail/views/receipt_detail_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/repositories/receipt_repository.dart';
import '../../../../domain/models/receipt.dart';
import '../../../../cloud/services/auth_service.dart';
import '../../../../services/currency_service.dart';
import '../../../../services/local_image_cache_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/widgets/app_snack_bar.dart';

enum _MenuAction { copyId, copyJson, delete }

/// Converted prices payload for a single line item in active currency.
class ConvertedLineItem {
  final double unitPrice;
  final double totalPrice;
  final String formattedUnitPrice;
  final String formattedTotalPrice;

  const ConvertedLineItem({
    required this.unitPrice,
    required this.totalPrice,
    required this.formattedUnitPrice,
    required this.formattedTotalPrice,
  });
}

/// Static, read-only Receipt Detail Screen.
///
/// Features a structured header layout:
/// - Circle image top-center (indented depth: -3)
/// - Merchant name (left) & Date (right)
/// - ID (left below merchant in small light gray font) & Amount + Currency (right below date)
/// - Categories centered horizontally
/// - Top-right 3-dot menu button (Copy ID, Copy JSON, Delete)
/// - Small rectangle edit button with icon that opens `/verification`
///
/// Body features a borderless table of line items with prices converted to target set currency.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  Receipt? _receipt;
  bool _isInitialized = false;
  final Map<String, List<ConvertedLineItem>> _convertedItemsCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      Object? extra;
      try {
        extra = GoRouterState.of(context).extra;
      } catch (_) {
        extra = null;
      }

      if (extra is Receipt) {
        _receipt = extra;
      } else if (extra is Map) {
        _receipt = Receipt.fromJson(extra.cast<String, dynamic>());
      }

      _isInitialized = true;
    }
  }

  /// Calculates or retrieves cached converted line item prices for active currency.
  List<ConvertedLineItem> _getConvertedLineItems(Receipt r) {
    final targetCurrency = CurrencyService.instance.currentCurrency;
    final cacheKey = '${r.id}_$targetCurrency';

    if (_convertedItemsCache.containsKey(cacheKey)) {
      return _convertedItemsCache[cacheKey]!;
    }

    final List<ConvertedLineItem> list = [];
    for (final item in r.lineItems) {
      final qty = item.quantity ?? 1.0;
      final origTotal = item.totalPrice ?? 0.0;
      final origUnit =
          item.unitPrice ?? (qty > 0 ? origTotal / qty : origTotal);

      final convertedUnit =
          CurrencyService.instance.convert(origUnit, r.currency);
      final convertedTotal =
          CurrencyService.instance.convert(origTotal, r.currency);

      final formattedUnit = CurrencyService.instance
          .format(convertedUnit, fromCurrencyCode: targetCurrency);
      final formattedTotal = CurrencyService.instance
          .format(convertedTotal, fromCurrencyCode: targetCurrency);

      list.add(ConvertedLineItem(
        unitPrice: convertedUnit,
        totalPrice: convertedTotal,
        formattedUnitPrice: formattedUnit,
        formattedTotalPrice: formattedTotal,
      ));
    }

    _convertedItemsCache[cacheKey] = list;
    return list;
  }

  void _openEditor() async {
    if (_receipt == null) return;
    await context.push('/edit-receipt', extra: _receipt);

    // Refresh static detail display from repository upon returning
    if (!mounted) return;
    final updated = ReceiptRepository.instance.receipts.firstWhere(
      (item) => item.id == _receipt!.id,
      orElse: () => _receipt!,
    );
    setState(() {
      _receipt = updated;
      _convertedItemsCache
          .clear(); // Clear cache to recalculate for updated receipt
    });
  }

  void _handleMenuAction(_MenuAction action, Receipt r) {
    switch (action) {
      case _MenuAction.copyId:
        Clipboard.setData(ClipboardData(text: r.id));
        AppSnackBar.show(
          context,
          message: 'Receipt ID copied to clipboard.',
        );
        break;
      case _MenuAction.copyJson:
        final jsonStr = const JsonEncoder.withIndent('  ').convert(r.toJson());
        Clipboard.setData(ClipboardData(text: jsonStr));
        AppSnackBar.show(
          context,
          message: 'Receipt JSON copied to clipboard.',
        );
        break;
      case _MenuAction.delete:
        _confirmDelete();
        break;
    }
  }

  void _confirmDelete() {
    final controller = AppThemeController.instance;
    final textPrimary = controller.textColor;
    final textSecondary = controller.secondaryTextColor;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Neumorphic(
          style: NeumorphicStyle(
            depth: 4,
            intensity: 0.8,
            color: controller.currentBaseColor,
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade400, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Delete Receipt?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this receipt? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: NeumorphicStyle(
                          depth: 3,
                          color: controller.currentBaseColor,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeumorphicButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          if (_receipt != null) {
                            await ReceiptRepository.instance
                                .deleteReceipt(_receipt!.id);
                          }
                          if (!mounted) return;
                          AppSnackBar.show(
                            context,
                            message: 'Receipt deleted.',
                            isError: true,
                          );
                          context.pop();
                        },
                        style: NeumorphicStyle(
                          depth: 3,
                          color: Colors.red.shade400,
                          boxShape: NeumorphicBoxShape.roundRect(
                              BorderRadius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [AppThemeController.instance, CurrencyService.instance]),
      builder: (context, _) {
        final controller = AppThemeController.instance;
        final textPrimary = controller.textColor;
        final textSecondary = controller.secondaryTextColor;
        final accent = controller.accentColor;
        final baseColor = controller.currentBaseColor;

        if (_receipt == null) {
          return NeumorphicBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Center(
                  child: NeumorphicButton(
                    onPressed: () => context.pop(),
                    style: NeumorphicStyle(
                      depth: 3,
                      boxShape: const NeumorphicBoxShape.circle(),
                      color: baseColor,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: textPrimary),
                  ),
                ),
                title: Text(
                  'Receipt Details',
                  style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              body: Center(
                child: Text('No receipt selected.',
                    style: TextStyle(color: textSecondary)),
              ),
            ),
          );
        }

        final r = _receipt!;
        final categoryColor = CategoryUtils.getCategoryColor(r.category);
        final formattedPrice = CurrencyService.instance
            .format(r.amount, fromCurrencyCode: r.currency);
        final convertedItems = _getConvertedLineItems(r);
        final allDetailTags = r.category
            .split(',')
            .map((c) => CategoryUtils.sanitize(c).trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();

        return NeumorphicBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Center(
                child: NeumorphicButton(
                  onPressed: () => context.pop(),
                  style: NeumorphicStyle(
                    depth: 3,
                    boxShape: const NeumorphicBoxShape.circle(),
                    color: baseColor,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: textPrimary),
                ),
              ),
              title: Text(
                'Receipt Details',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              centerTitle: true,
              actions: [
                // Top-Right 3-Dot Overflow Menu Button
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: PopupMenuButton<_MenuAction>(
                      onSelected: (action) => _handleMenuAction(action, r),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: baseColor,
                      elevation: 6,
                      icon: Neumorphic(
                        style: NeumorphicStyle(
                          depth: 3,
                          boxShape: const NeumorphicBoxShape.circle(),
                          color: baseColor,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.more_vert_rounded,
                            color: textPrimary, size: 18),
                      ),
                      itemBuilder: (ctx) => [
                        PopupMenuItem<_MenuAction>(
                          value: _MenuAction.copyId,
                          child: Row(
                            children: [
                              Icon(Icons.content_copy_rounded,
                                  size: 16, color: accent),
                              const SizedBox(width: 10),
                              Text('Copy Receipt ID',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem<_MenuAction>(
                          value: _MenuAction.copyJson,
                          child: Row(
                            children: [
                              Icon(Icons.code_rounded, size: 16, color: accent),
                              const SizedBox(width: 10),
                              Text('Copy as JSON',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<_MenuAction>(
                          value: _MenuAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 16, color: Colors.red.shade400),
                              const SizedBox(width: 10),
                              Text('Delete Receipt',
                                  style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // ── Header Card ─────────────────────────────────────────
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 4,
                        intensity: 0.8,
                        color: baseColor,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(20)),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // 1. Top Centre Receipt Image (90x90 Rounded Square with Fullscreen Zoom)
                          Center(
                            child: _buildReceiptImageHeader(
                              r,
                              categoryColor,
                              textSecondary,
                              accent,
                              baseColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Merchant Name (Left) & Date (Right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  r.merchant,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.date,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // 3. ID (Left below merchant) & Amount + Currency (Right below date)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '#ID: ${r.id.length > 14 ? "${r.id.substring(0, 14)}..." : r.id}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Text(
                                formattedPrice,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 4. Categories (Last in header, centre, multi-row wrapped)
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 6,
                              children: allDetailTags.map((tag) {
                                final tagColor =
                                    CategoryUtils.getCategoryColor(tag);
                                return Neumorphic(
                                  style: NeumorphicStyle(
                                    depth: -2,
                                    intensity: 0.8,
                                    color: tagColor.withValues(alpha: 0.2),
                                    boxShape: NeumorphicBoxShape.roundRect(
                                        BorderRadius.circular(12)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CategoryUtils.getCategoryIcon(tag),
                                        size: 14,
                                        color: tagColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: tagColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 5. Small Rectangle Edit Button with Icon
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _openEditor,
                              child: Neumorphic(
                                style: NeumorphicStyle(
                                  depth: 3,
                                  intensity: 0.8,
                                  color: baseColor,
                                  boxShape: NeumorphicBoxShape.roundRect(
                                      BorderRadius.circular(8)),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 14, color: accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Body Card (Borderless Line Items Table with Converted Currency) ──
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: 4,
                        intensity: 0.8,
                        color: baseColor,
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(20)),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ITEMS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                CurrencyService.instance.currentCurrency,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (r.lineItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No line items recorded.',
                                  style: TextStyle(
                                      fontSize: 13, color: textSecondary),
                                ),
                              ),
                            )
                          else
                            // Borderless Table with Converted Prices (Task 3)
                            Table(
                              border: const TableBorder(),
                              columnWidths: const {
                                0: FlexColumnWidth(3.0), // Description
                                1: FlexColumnWidth(1.0), // Qty
                                2: FlexColumnWidth(
                                    1.8), // Unit Price (Converted)
                                3: FlexColumnWidth(
                                    1.8), // Total Price (Converted)
                              },
                              children: [
                                // Table Header Row
                                TableRow(
                                  children: [
                                    _buildTableHeader(
                                        'Item', textSecondary, TextAlign.left),
                                    _buildTableHeader(
                                        'Qty', textSecondary, TextAlign.center),
                                    _buildTableHeader(
                                        'Unit', textSecondary, TextAlign.right),
                                    _buildTableHeader('Total', textSecondary,
                                        TextAlign.right),
                                  ],
                                ),

                                // Spacing row
                                TableRow(
                                  children: List.generate(
                                      4, (_) => const SizedBox(height: 8)),
                                ),

                                // Table Data Rows with Cached Converted Currency
                                ...List.generate(r.lineItems.length, (idx) {
                                  final item = r.lineItems[idx];
                                  final converted = convertedItems[idx];
                                  final qty = item.quantity ?? 1.0;
                                  final qtyStr = qty % 1 == 0
                                      ? qty.toInt().toString()
                                      : qty.toStringAsFixed(1);
                                  final isDiscount = (item.totalPrice != null &&
                                          item.totalPrice! < 0) ||
                                      (item.unitPrice != null &&
                                          item.unitPrice! < 0);
                                  const discountColor = Color(0xFF34C759);

                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Text(
                                          item.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDiscount
                                                ? discountColor
                                                : textPrimary,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Text(
                                          qtyStr,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDiscount
                                                ? discountColor
                                                : textSecondary,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Text(
                                          converted.formattedUnitPrice,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDiscount
                                                ? discountColor
                                                : textSecondary,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Text(
                                          converted.formattedTotalPrice,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDiscount
                                                ? discountColor
                                                : textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Divider(
                              color: textSecondary.withValues(alpha: 0.15),
                              height: 1),
                          const SizedBox(height: 12),
                          _buildSummaryRow(
                            'Grand Total',
                            formattedPrice,
                            textPrimary,
                            accent,
                            isBold: true,
                            fontSize: 16,
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

  Widget _buildReceiptImageHeader(
    Receipt r,
    Color categoryColor,
    Color textSecondary,
    Color accent,
    Color baseColor,
  ) {
    if (r.imagePath == null || r.imagePath!.isEmpty) {
      return Neumorphic(
        style: NeumorphicStyle(
          depth: -2,
          intensity: 0.8,
          color: categoryColor.withValues(alpha: 0.08),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
        ),
        child: SizedBox(
          width: 90,
          height: 90,
          child: _buildNoImageFallback(categoryColor, textSecondary),
        ),
      );
    }

    if (File(r.imagePath!).existsSync()) {
      return _buildReceiptImageCard(
        FileImage(File(r.imagePath!)),
        r.merchant,
        categoryColor,
        textSecondary,
        accent,
        baseColor,
      );
    }

    // In guest mode, if the local file is not found, fallback to 'No image' immediately
    if (!AuthService.instance.isLoggedIn) {
      return Neumorphic(
        style: NeumorphicStyle(
          depth: -2,
          intensity: 0.8,
          color: categoryColor.withValues(alpha: 0.08),
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
        ),
        child: SizedBox(
          width: 90,
          height: 90,
          child: _buildNoImageFallback(categoryColor, textSecondary),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: LocalImageCacheService.instance.getOrFetchReceiptImage(
        receiptId: r.id,
        localOrCloudPath: r.imagePath,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _buildReceiptImageCard(
            FileImage(snapshot.data!),
            r.merchant,
            categoryColor,
            textSecondary,
            accent,
            baseColor,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Neumorphic(
            style: NeumorphicStyle(
              depth: -2,
              intensity: 0.8,
              color: categoryColor.withValues(alpha: 0.08),
              boxShape:
                  NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ),
            ),
          );
        }
        return Neumorphic(
          style: NeumorphicStyle(
            depth: -2,
            intensity: 0.8,
            color: categoryColor.withValues(alpha: 0.08),
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
          ),
          child: SizedBox(
            width: 90,
            height: 90,
            child: _buildNoImageFallback(categoryColor, textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildReceiptImageCard(
    ImageProvider imageProvider,
    String merchant,
    Color categoryColor,
    Color textSecondary,
    Color accent,
    Color baseColor,
  ) {
    return GestureDetector(
      onTap: () =>
          _showEnlargedReceiptDialog(context, imageProvider, merchant),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Neumorphic(
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.85,
              color: baseColor,
              boxShape:
                  NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
              border: NeumorphicBorder(
                color: accent.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _buildNoImageFallback(categoryColor, textSecondary),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Neumorphic(
              style: NeumorphicStyle(
                depth: 2,
                boxShape: const NeumorphicBoxShape.circle(),
                color: baseColor,
              ),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.zoom_in_rounded, size: 14, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoImageFallback(Color categoryColor, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 32,
            color: categoryColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            "No image",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnlargedReceiptDialog(
    BuildContext context,
    ImageProvider imageProvider,
    String merchant,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8),
                    child: Text(
                      merchant,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Interactive Zoomable / Pannable Image
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        clipBehavior: Clip.none,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Pinch or double tap to zoom • Drag to pan",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Close Button Top-Right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String text, Color color, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    bool isBold = false,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

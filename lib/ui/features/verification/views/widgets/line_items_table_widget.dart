// File: lib/ui/features/verification/views/widgets/line_items_table_widget.dart
//
// Neumorphic borderless table for displaying and editing receipt line items.
// Table layout:
//   | Qt   | Desc                    | Amt       | [✏️] |
//   |------|-------------------------|-----------|------|
//   |  2   | Milk 1L                 | USD 4.50  |  ✏️  |
//   |  1   | Coffee Latte            | USD 5.90  |  ✏️  |

import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../domain/models/line_item.dart';

/// Neumorphic borderless line items table with indented header row and
/// protruded edit buttons per row.
class LineItemsTableWidget extends StatefulWidget {
  final List<LineItem> lineItems;
  final String currency;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final ValueChanged<List<LineItem>> onChanged;

  const LineItemsTableWidget({
    super.key,
    required this.lineItems,
    required this.currency,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<LineItemsTableWidget> createState() => _LineItemsTableWidgetState();
}

class _LineItemsTableWidgetState extends State<LineItemsTableWidget> {
  late List<LineItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.lineItems);
  }

  @override
  void didUpdateWidget(covariant LineItemsTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineItems != widget.lineItems) {
      _items = List.from(widget.lineItems);
    }
  }

  void _updateItems(List<LineItem> updated) {
    setState(() => _items = updated);
    widget.onChanged(updated);
  }

  void _onEditTap(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _LineItemEditDialog(
        item: _items[index],
        currency: widget.currency,
        textPrimary: widget.textPrimary,
        textSecondary: widget.textSecondary,
        accent: widget.accent,
        onSave: (updated) {
          final list = List<LineItem>.from(_items);
          list[index] = updated;
          _updateItems(list);
        },
        onDelete: () {
          final list = List<LineItem>.from(_items);
          list.removeAt(index);
          _updateItems(list);
        },
      ),
    );
  }

  void _onAddTap() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _LineItemEditDialog(
        item: const LineItem(description: ''),
        currency: widget.currency,
        textPrimary: widget.textPrimary,
        textSecondary: widget.textSecondary,
        accent: widget.accent,
        onSave: (newItem) {
          final list = List<LineItem>.from(_items)..add(newItem);
          _updateItems(list);
        },
        onDelete: null, // no delete for new item
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          'Line Items',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: widget.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // ── Indented header row (sunken neumorphic depth: -2) ──────────────
        Neumorphic(
          style: NeumorphicStyle(
            depth: -2,
            intensity: 0.7,
            color: NeumorphicTheme.baseColor(context),
            boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(10)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    'Qt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Desc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    'Amt',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 36), // hidden "Edit" column header space
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // ── Line item rows ──────────────────────────────────────────────────
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'No line items extracted.',
                style: TextStyle(fontSize: 13, color: widget.textSecondary),
              ),
            ),
          )
        else
          ...List.generate(_items.length, (i) => _buildRow(_items[i], i)),

        const SizedBox(height: 8),

        // ── Add Item button ─────────────────────────────────────────────────
        Center(
          child: NeumorphicButton(
            onPressed: _onAddTap,
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.8,
              color: NeumorphicTheme.baseColor(context),
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: widget.accent),
                const SizedBox(width: 6),
                Text(
                  'Add Line Item',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(LineItem item, int index) {
    final price = item.totalPrice ?? (item.unitPrice != null && item.quantity != null
        ? item.unitPrice! * item.quantity!
        : item.unitPrice);
    final qtyStr = item.quantity != null
        ? (item.quantity! % 1 == 0
            ? item.quantity!.toInt().toString()
            : item.quantity!.toStringAsFixed(1))
        : '—';
    final amtStr = price != null ? price.toStringAsFixed(2) : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Qt column
          SizedBox(
            width: 38,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                qtyStr,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Desc column
          Expanded(
            child: Text(
              item.description,
              style: TextStyle(fontSize: 13, color: widget.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Amt column
          SizedBox(
            width: 76,
            child: Text(
              amtStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Protruded edit button (depth: 3 = raised/convex)
          NeumorphicButton(
            onPressed: () => _onEditTap(index),
            style: NeumorphicStyle(
              depth: 3,
              intensity: 0.85,
              color: NeumorphicTheme.baseColor(context),
              boxShape: const NeumorphicBoxShape.circle(),
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.edit_outlined, size: 14, color: widget.accent),
          ),
        ],
      ),
    );
  }
}

// ── Line Item Edit Dialog ────────────────────────────────────────────────────

class _LineItemEditDialog extends StatefulWidget {
  final LineItem item;
  final String currency;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final ValueChanged<LineItem> onSave;
  final VoidCallback? onDelete;

  const _LineItemEditDialog({
    required this.item,
    required this.currency,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_LineItemEditDialog> createState() => _LineItemEditDialogState();
}

class _LineItemEditDialogState extends State<_LineItemEditDialog> {
  late TextEditingController _descController;
  late TextEditingController _qtyController;
  late TextEditingController _amtController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.item.description);
    _qtyController = TextEditingController(
      text: widget.item.quantity?.toString() ?? '',
    );
    final price = widget.item.totalPrice ??
        (widget.item.unitPrice != null && widget.item.quantity != null
            ? widget.item.unitPrice! * widget.item.quantity!
            : widget.item.unitPrice);
    _amtController = TextEditingController(
      text: price != null ? price.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _qtyController.dispose();
    _amtController.dispose();
    super.dispose();
  }

  void _save() {
    final qty = double.tryParse(_qtyController.text.trim());
    final amt = double.tryParse(_amtController.text.trim());
    final updated = LineItem(
      description: _descController.text.trim(),
      quantity: qty,
      totalPrice: amt,
      unitPrice: widget.item.unitPrice,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final base = NeumorphicTheme.baseColor(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Neumorphic(
        style: NeumorphicStyle(
          depth: 4,
          intensity: 0.75,
          color: base,
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog title
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: widget.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.onDelete != null ? 'Edit Line Item' : 'Add Line Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description field
              _buildDialogLabel('Description'),
              const SizedBox(height: 6),
              _buildNeumorphicField(
                controller: _descController,
                hint: 'e.g. Coffee Latte',
                keyboardType: TextInputType.text,
                textPrimary: widget.textPrimary,
                base: base,
              ),
              const SizedBox(height: 14),

              // Qty & Amt row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogLabel('Quantity (Qt)'),
                        const SizedBox(height: 6),
                        _buildNeumorphicField(
                          controller: _qtyController,
                          hint: 'e.g. 2',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          formatter: FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          textPrimary: widget.textPrimary,
                          base: base,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogLabel('Amount (${widget.currency})'),
                        const SizedBox(height: 6),
                        _buildNeumorphicField(
                          controller: _amtController,
                          hint: 'e.g. 4.50',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          formatter: FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          textPrimary: widget.accent,
                          base: base,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons row
              Row(
                children: [
                  // Delete button (only for existing items)
                  if (widget.onDelete != null) ...[
                    NeumorphicButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDelete!();
                      },
                      style: NeumorphicStyle(
                        depth: 3,
                        intensity: 0.8,
                        color: base,
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),

                  // Cancel button
                  NeumorphicButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: NeumorphicStyle(
                      depth: 3,
                      intensity: 0.8,
                      color: base,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Save button
                  NeumorphicButton(
                    onPressed: _save,
                    style: NeumorphicStyle(
                      depth: 3,
                      intensity: 0.85,
                      color: widget.accent,
                      boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: widget.textSecondary,
      ),
    );
  }

  Widget _buildNeumorphicField({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required Color textPrimary,
    required Color base,
    TextInputFormatter? formatter,
    bool isBold = false,
  }) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -3,
        intensity: 0.85,
        color: base,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(10)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatter != null ? [formatter] : null,
        style: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: widget.textSecondary.withValues(alpha: 0.5), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

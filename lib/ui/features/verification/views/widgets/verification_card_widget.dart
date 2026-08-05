// File: lib/ui/features/verification/views/widgets/verification_card_widget.dart

import 'package:flutter/services.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import '../../../../../domain/models/line_item.dart';
import '../../../../../domain/models/receipt.dart';
import '../../../../../services/currency_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'line_items_table_widget.dart';

/// Modular Neumorphic Card Widget allowing inline editing of receipt details.
class VerificationCardWidget extends StatefulWidget {
  final Receipt receipt;
  final ValueChanged<Receipt> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const VerificationCardWidget({
    super.key,
    required this.receipt,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  State<VerificationCardWidget> createState() => _VerificationCardWidgetState();
}

class _VerificationCardWidgetState extends State<VerificationCardWidget> {
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  late TextEditingController _amountController;
  late String _selectedCurrency;
  late List<String> _selectedCategories;
  late List<LineItem> _lineItems;
  bool _isAutoCalculate = true;

  final List<String> _categories = [
    'Groceries 🛒',
    'Dining 🍔',
    'Transport 🚗',
    'Shopping 🛍️',
    'Electronics 📱',
    'General 🧾',
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant VerificationCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt.id != widget.receipt.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    _merchantController = TextEditingController(text: widget.receipt.merchant);
    _dateController = TextEditingController(text: widget.receipt.date);
    _amountController = TextEditingController(text: widget.receipt.amount.toStringAsFixed(2));
    _selectedCurrency = widget.receipt.currency;
    // Parse comma-separated categories from the stored field
    _selectedCategories = widget.receipt.category
        .split(', ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _lineItems = List.from(widget.receipt.lineItems);
    if (_lineItems.isEmpty && widget.receipt.items.isNotEmpty) {
      _lineItems = Receipt.parseLegacyItemsToLineItems(widget.receipt.items);
    }
    _isAutoCalculate = _lineItems.isNotEmpty;
    if (_isAutoCalculate) {
      _recalculateTotalFromLineItems();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyChange();
    });
  }

  void _recalculateTotalFromLineItems() {
    if (!_isAutoCalculate) return;
    final double total = _lineItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    _amountController.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final String rawAmt = _amountController.text;
    final double amt = (rawAmt.isEmpty || double.tryParse(rawAmt) == null)
        ? widget.receipt.amount
        : double.parse(rawAmt);

    // Format legacy string items list to stay synchronized with lineItems
    final List<String> legacyItems = _lineItems.map((li) {
      final baseP = li.effectiveUnitPrice;
      final priceStr = baseP > 0 ? ' - $_selectedCurrency ${baseP.toStringAsFixed(2)}' : '';
      return '${li.description}$priceStr';
    }).toList();

    widget.onChanged(
      widget.receipt.copyWith(
        merchant: _merchantController.text.trim(),
        date: _dateController.text.trim(),
        amount: amt,
        currency: _selectedCurrency,
        category: _selectedCategories.join(', '),
        lineItems: _lineItems,
        items: legacyItems,
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      // Try to parse existing date text (e.g. "Aug 01, 2026")
      final parts = _dateController.text.split(' ');
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      if (parts.length == 3) {
        final month = months.indexOf(parts[0]) + 1;
        final day = int.parse(parts[1].replaceAll(',', ''));
        final year = int.parse(parts[2]);
        initial = DateTime(year, month, day);
      } else {
        initial = DateTime.now();
      }
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final formatted = '${months[picked.month - 1]} ${picked.day.toString().padLeft(2, '0')}, ${picked.year}';
      setState(() {
        _dateController.text = formatted;
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeumorphicCardWidget(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Merchant Field
          _buildLabel("Merchant"),
          const SizedBox(height: 6),
          Neumorphic(
            style: NeumorphicStyle(
              depth: -3,
              intensity: 0.85,
              color: NeumorphicTheme.baseColor(context),
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
            ),
            child: TextField(
              controller: _merchantController,
              style: TextStyle(color: widget.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
              onChanged: (_) => _notifyChange(),
            ),
          ),
          const SizedBox(height: 16),

          // Date & Currency Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Date"),
                    const SizedBox(height: 6),
                    Neumorphic(
                      style: NeumorphicStyle(
                        depth: -3,
                        intensity: 0.85,
                        color: NeumorphicTheme.baseColor(context),
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                      ),
                      child: TextField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        style: TextStyle(color: widget.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: widget.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Currency"),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: NeumorphicTheme.baseColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          dropdownColor: NeumorphicTheme.baseColor(context),
                          style: TextStyle(color: widget.textPrimary, fontWeight: FontWeight.bold),
                          items: CurrencyService.supportedCurrencies.keys.map((code) {
                            return DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCurrency = val);
                              _notifyChange();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Field
          _buildLabel("Amount (${CurrencyService.supportedCurrencies[_selectedCurrency]?.symbol ?? '\$'})"),
          const SizedBox(height: 6),
          Neumorphic(
            style: NeumorphicStyle(
              depth: -3,
              intensity: 0.85,
              color: NeumorphicTheme.baseColor(context),
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
            ),
            child: TextField(
              controller: _amountController,
              readOnly: _isAutoCalculate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: TextStyle(color: widget.accent, fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
              onChanged: (_) => _notifyChange(),
            ),
          ),
          const SizedBox(height: 8),

          // Auto-calculate Total Amount Switch Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isAutoCalculate ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
                    size: 16,
                    color: _isAutoCalculate ? widget.accent : widget.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-calculate total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isAutoCalculate ? widget.accent : widget.textSecondary,
                    ),
                  ),
                ],
              ),
              NeumorphicSwitch(
                value: _isAutoCalculate,
                style: NeumorphicSwitchStyle(
                  activeTrackColor: widget.accent.withValues(alpha: 0.3),
                  activeThumbColor: widget.accent,
                  inactiveThumbColor: widget.textSecondary.withValues(alpha: 0.5),
                ),
                onChanged: (val) {
                  setState(() {
                    _isAutoCalculate = val;
                    if (_isAutoCalculate) {
                      _recalculateTotalFromLineItems();
                    }
                  });
                  _notifyChange();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Indented Horizontal Scrollable Category Track
          _buildLabel("Category"),
          const SizedBox(height: 8),
          Neumorphic(
            style: NeumorphicStyle(
              depth: -3,
              intensity: 0.85,
              color: NeumorphicTheme.baseColor(context),
              boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategories.contains(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NeumorphicButton(
                      onPressed: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(cat);
                          } else {
                            _selectedCategories.add(cat);
                          }
                        });
                        _notifyChange();
                      },
                      style: NeumorphicStyle(
                        depth: isSelected ? -2 : 3,
                        intensity: 0.85,
                        color: isSelected
                            ? widget.accent.withValues(alpha: 0.2)
                            : NeumorphicTheme.baseColor(context),
                        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(14)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? widget.accent : widget.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Line Items table (structured from backend Vision AI or empty)
          const SizedBox(height: 20),
          LineItemsTableWidget(
            lineItems: _lineItems,
            currency: _selectedCurrency,
            textPrimary: widget.textPrimary,
            textSecondary: widget.textSecondary,
            accent: widget.accent,
            onChanged: (updatedItems) {
              setState(() {
                _lineItems = updatedItems;
                if (_isAutoCalculate) {
                  _recalculateTotalFromLineItems();
                }
              });
              _notifyChange();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: widget.textSecondary,
      ),
    );
  }
}

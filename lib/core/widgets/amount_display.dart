import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reciept_logging/core/theme/app_theme.dart';

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? style;
  final bool large;

  const AmountDisplay({
    super.key,
    required this.amount,
    this.currency = 'USD',
    this.style,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.currency(
      symbol: _currencySymbol(currency),
      decimalDigits: 2,
    ).format(amount);

    return Text(
      formatted,
      style: style ?? (large ? AppTheme.amountLarge : AppTheme.bodyLarge.copyWith(
        color: AppTheme.accentColor,
        fontWeight: FontWeight.w600,
      )),
    );
  }

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'MYR': return 'RM ';
      case 'SGD': return 'S\$';
      default: return '$code ';
    }
  }
}

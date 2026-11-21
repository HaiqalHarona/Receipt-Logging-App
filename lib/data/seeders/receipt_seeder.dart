// File: lib/data/seeders/receipt_seeder.dart

import 'dart:math';
import '../../domain/models/line_item.dart';
import '../../domain/models/receipt.dart';
import '../repositories/receipt_repository.dart';

/// Database seeder for populating 24 realistic receipt records
/// spanning the last 12 months (2 receipts for each month).
class ReceiptSeeder {
  ReceiptSeeder._();

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  static const List<String> _merchants = [
    'Target Superstore',
    'Shell Gas Station',
    'Whole Foods Market',
    'Apple Store NYC',
    'Blue Bottle Coffee',
    'Trader Joe\'s',
    'Costco Wholesale',
    'Starbucks Coffee',
    'Best Buy',
    'CVS Pharmacy',
    'Chevron Gas',
    'Home Depot',
    'Amazon Fresh',
    'Walmart Supercenter',
    'Walgreens',
  ];

  static const List<String> _categories = [
    'Groceries',
    'Dining',
    'Transport',
    'Electronics',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Health',
  ];

  static const Map<String, List<String>> _itemCatalog = {
    'Groceries': [
      'Organic Milk 1 Gal',
      'Avocados Bag 5ct',
      'Almond Butter 16oz',
      'Greek Yogurt 32oz',
      'Paper Towels 6pk',
      'Sourdough Bread',
      'Fresh Strawberries',
    ],
    'Dining': [
      'Iced Latte',
      'Artisanal Pizza',
      'Avocado Toast',
      'Ramen Bowl',
      'Sparkling Water',
      'Cheeseburger Combo',
    ],
    'Transport': [
      'Unleaded Gas 12Gal',
      'EV Fast Charge',
      'Subway Day Pass',
      'Parking Fee',
    ],
    'Electronics': [
      'USB-C Charging Cable',
      'Wireless Mouse',
      'Screen Protector',
      'Bluetooth Earbuds',
    ],
    'Entertainment': [
      'Movie Cinema Tickets',
      'Concert Pass',
      'Board Game Set',
    ],
    'Shopping': [
      'Cotton T-Shirt',
      'Desk Lamp LED',
      'Notebook Set',
    ],
    'Utilities': [
      'Electricity Bill Payment',
      'Water Supply Bill',
      'Fiber Internet Bill',
    ],
    'Health': [
      'Vitamin C 1000mg',
      'Hand Sanitizer 16oz',
      'First Aid Kit',
    ],
  };

  /// Generates 24 realistic receipt records spanning the last 12 months (2 per month).
  static List<Receipt> generate24Receipts({Random? randomOverride}) {
    final rand =
        randomOverride ?? Random(42); // Deterministic seed for consistency
    final List<Receipt> generated = [];
    final now = DateTime.now();

    int idCounter = 1;

    // Generate 2 receipts for each of the last 12 months (11 months ago to current month)
    for (int i = 11; i >= 0; i--) {
      final yearMonth = DateTime(now.year, now.month - i, 1);
      final daysInMonth = DateTime(yearMonth.year, yearMonth.month + 1, 0).day;

      // Two dates in the month (e.g. day 5..12 and day 18..26)
      final day1 = 3 + rand.nextInt(min(10, daysInMonth - 2));
      final day2 = min(15 + rand.nextInt(10), daysInMonth);

      final datesInMonth = [
        DateTime(yearMonth.year, yearMonth.month, day1, 10 + rand.nextInt(8),
            rand.nextInt(59)),
        DateTime(yearMonth.year, yearMonth.month, day2, 11 + rand.nextInt(8),
            rand.nextInt(59)),
      ];

      for (final receiptDate in datesInMonth) {
        final merchant = _merchants[rand.nextInt(_merchants.length)];

        // Select 1 to 3 unique categories (emoji-free)
        final categoryCount = 1 + rand.nextInt(3);
        final shuffledCat = List<String>.from(_categories)..shuffle(rand);
        final selectedCategories = shuffledCat.take(categoryCount).toList();
        final categoryString = selectedCategories.join(', ');

        // Generate 1 to 5 line items
        final lineItemCount = 1 + rand.nextInt(5);
        final List<LineItem> lineItems = [];
        double receiptTotal = 0.0;

        for (int k = 0; k < lineItemCount; k++) {
          final primaryCat =
              selectedCategories[rand.nextInt(selectedCategories.length)];
          final catalog =
              _itemCatalog[primaryCat] ?? _itemCatalog['Groceries']!;
          final description = catalog[rand.nextInt(catalog.length)];

          // Price between $5.00 and $30.00
          final rawPrice = 5.0 + (rand.nextDouble() * 25.0);
          final unitPrice = (rawPrice * 100).round() / 100.0;

          // Quantity between 1 and 6
          final quantity = (1 + rand.nextInt(6)).toDouble();
          final itemTotal = ((unitPrice * quantity) * 100).round() / 100.0;

          lineItems.add(
            LineItem(
              description: description,
              quantity: quantity,
              unitPrice: unitPrice,
              totalPrice: itemTotal,
            ),
          );

          receiptTotal += itemTotal;
        }

        receiptTotal = (receiptTotal * 100).round() / 100.0;
        final dateString =
            '${_monthNames[receiptDate.month - 1]} ${receiptDate.day.toString().padLeft(2, '0')}, ${receiptDate.year}';

        generated.add(
          Receipt(
            id: 'seed-receipt-${idCounter.toString().padLeft(3, '0')}',
            merchant: merchant,
            date: dateString,
            amount: receiptTotal,
            currency: 'USD',
            category: categoryString,
            createdAt: receiptDate,
            lineItems: lineItems,
          ),
        );

        idCounter++;
      }
    }

    return generated;
  }

  /// Seeds 24 receipts into the [ReceiptRepository].
  static Future<void> seedDatabase() async {
    final receipts = generate24Receipts();
    await ReceiptRepository.instance.saveAllReceipts(receipts);
  }
}

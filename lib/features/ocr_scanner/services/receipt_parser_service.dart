import 'dart:math';
import '../models/parsed_receipt.dart';

class ReceiptPreset {
  final String title;
  final String subtitle;
  final String merchant;
  final double total;
  final String currency;
  final List<ParsedReceiptItem> items;
  final String rawReceiptText;

  const ReceiptPreset({
    required this.title,
    required this.subtitle,
    required this.merchant,
    required this.total,
    required this.currency,
    required this.items,
    required this.rawReceiptText,
  });
}

class ReceiptParserService {
  ReceiptParserService._();

  static final List<ReceiptPreset> sampleReceipts = [
    const ReceiptPreset(
      title: 'Seafood Harbour Dinner',
      subtitle: 'Dahab Promenade - 4 Guests',
      merchant: 'Ali Baba Seafood Grill',
      total: 124.50,
      currency: 'USD',
      items: [
        ParsedReceiptItem(name: 'Grilled Red Snapper (1kg)', price: 45.00),
        ParsedReceiptItem(name: 'Jumbo Prawns Platter', price: 38.50),
        ParsedReceiptItem(name: 'Mezze Salad & Hummus', price: 16.00),
        ParsedReceiptItem(name: 'Fresh Mango Juices (x4)', price: 15.00),
        ParsedReceiptItem(name: 'Service Charge 8%', price: 10.00),
      ],
      rawReceiptText: '''
ALI BABA SEAFOOD GRILL
Dahab Waterfront Promenade, Egypt
Date: 2026-10-21  Time: 20:45
Receipt #: 049281
------------------------------------
1x Grilled Red Snapper       \$45.00
1x Jumbo Prawns Platter       \$38.50
1x Mezze Salad & Hummus       \$16.00
4x Fresh Mango Juices         \$15.00
Service Charge 8%             \$10.00
------------------------------------
SUBTOTAL:                     \$114.50
TAX & FEES:                   \$10.00
TOTAL AMOUNT:                 \$124.50
THANK YOU FOR DINING WITH US!
''',
    ),
    const ReceiptPreset(
      title: 'Highway Fuel & Snacks',
      subtitle: 'Suez-Sinai Roadtrip Stop',
      merchant: 'ChillOut Highway Express',
      total: 58.20,
      currency: 'USD',
      items: [
        ParsedReceiptItem(name: 'Octane 95 Full Tank', price: 42.00),
        ParsedReceiptItem(name: 'Iced Latte x2', price: 8.50),
        ParsedReceiptItem(name: 'Energy Bars & Chips', price: 7.70),
      ],
      rawReceiptText: '''
CHILLOUT HIGHWAY EXPRESS
Km 72 Suez Road Service Area
Date: 2026-10-20  14:15
Terminal: #03 POS
------------------------------------
Octane 95 Fuel (40L)          \$42.00
Iced Lattes (x2)               \$8.50
Snack Pack & Chips             \$7.70
------------------------------------
TOTAL DUE:                    \$58.20
PAID BY VISA: ************4819
AUTH CODE: 981240
''',
    ),
    const ReceiptPreset(
      title: 'Camp Grocery Run',
      subtitle: 'Water, Fruit & Supplies',
      merchant: 'Blue Hole Mini Market',
      total: 35.80,
      currency: 'USD',
      items: [
        ParsedReceiptItem(name: 'Mineral Water (Pack of 12)', price: 12.00),
        ParsedReceiptItem(name: 'Fresh Fruits (Bananas & Oranges)', price: 9.30),
        ParsedReceiptItem(name: 'Sunscreen SPF 50', price: 14.50),
      ],
      rawReceiptText: '''
BLUE HOLE MINI MARKET
Dahab North Coast
Date: 2026-10-21  10:30
------------------------------------
12x Mineral Water 1.5L        \$12.00
Assorted Fresh Fruits          \$9.30
Sunscreen SPF 50              \$14.50
------------------------------------
TOTAL:                        \$35.80
CASH TENDERED:                \$40.00
CHANGE:                        \$4.20
''',
    ),
  ];

  /// Parses arbitrary raw text (from camera OCR or manual paste)
  static ParsedReceipt parseText(String text, {String defaultCurrency = 'USD'}) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String merchant = 'Scanned Receipt';
    DateTime date = DateTime.now();
    double totalAmount = 0.0;
    double? tax;
    final List<ParsedReceiptItem> items = [];
    final List<String> rawTokens = [];

    if (lines.isNotEmpty) {
      merchant = lines.first;
    }

    final totalRegex = RegExp(r'(?:TOTAL|AMOUNT DUE|BALANCE|SUM|NET|TOTAL DUE)[\s:]*[$€£E£]?\s*(\d+[.,]\d{2})', caseSensitive: false);
    final taxRegex = RegExp(r'(?:TAX|VAT)[\s:]*[$€£E£]?\s*(\d+[.,]\d{2})', caseSensitive: false);
    final dateRegex = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})|(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})');
    final itemLineRegex = RegExp(r'^(.+?)\s+[$€£E£]?(\d+[.,]\d{2})$');

    for (final line in lines) {
      // Split into tokens for interactive OCR chip picking
      final words = line.split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.length > 2 && !rawTokens.contains(w)) {
          rawTokens.add(w);
        }
      }

      // Check date
      final dateMatch = dateRegex.firstMatch(line);
      if (dateMatch != null) {
        final dateStr = dateMatch.group(0)!;
        try {
          date = DateTime.parse(dateStr.replaceAll('/', '-'));
        } catch (_) {}
      }

      // Check total
      final totalMatch = totalRegex.firstMatch(line);
      if (totalMatch != null) {
        final numStr = totalMatch.group(1)!.replaceAll(',', '.');
        totalAmount = double.tryParse(numStr) ?? totalAmount;
        continue;
      }

      // Check tax
      final taxMatch = taxRegex.firstMatch(line);
      if (taxMatch != null) {
        final taxStr = taxMatch.group(1)!.replaceAll(',', '.');
        tax = double.tryParse(taxStr);
        continue;
      }

      // Check item
      final itemMatch = itemLineRegex.firstMatch(line);
      if (itemMatch != null) {
        final itemName = itemMatch.group(1)!.replaceAll(RegExp(r'[-_*]'), '').trim();
        final itemPriceStr = itemMatch.group(2)!.replaceAll(',', '.');
        final itemPrice = double.tryParse(itemPriceStr);
        if (itemPrice != null && !itemName.toUpperCase().contains('TOTAL') && !itemName.toUpperCase().contains('SUBTOTAL')) {
          items.add(ParsedReceiptItem(name: itemName, price: itemPrice));
        }
      }
    }

    // Fallback if total wasn't matched directly from totalRegex: take largest item or sum of items
    if (totalAmount == 0.0 && items.isNotEmpty) {
      totalAmount = items.fold(0.0, (sum, it) => sum + it.price);
    }

    return ParsedReceipt(
      merchant: merchant,
      date: date,
      totalAmount: totalAmount > 0 ? totalAmount : 25.00,
      tax: tax,
      currency: defaultCurrency,
      items: items,
      rawTokens: rawTokens.take(25).toList(),
    );
  }
}

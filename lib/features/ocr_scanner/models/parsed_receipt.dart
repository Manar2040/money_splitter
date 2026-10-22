class ParsedReceiptItem {
  final String name;
  final double price;
  final int quantity;

  const ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

class ParsedReceipt {
  final String merchant;
  final DateTime date;
  final double totalAmount;
  final double? tax;
  final String currency;
  final List<ParsedReceiptItem> items;
  final List<String> rawTokens; // Recognized text bounding chips for interactive tapping

  const ParsedReceipt({
    required this.merchant,
    required this.date,
    required this.totalAmount,
    this.tax,
    this.currency = 'USD',
    required this.items,
    required this.rawTokens,
  });
}

class DebtTransaction {
  final String id;
  final String fromMemberId; // Who owes the money (Debtor)
  final String toMemberId; // Who receives the money (Creditor)
  final double amount;
  final String currencyCode;
  final bool isSettled;

  const DebtTransaction({
    required this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.currencyCode,
    this.isSettled = false,
  });

  DebtTransaction copyWith({
    String? id,
    String? fromMemberId,
    String? toMemberId,
    double? amount,
    String? currencyCode,
    bool? isSettled,
  }) {
    return DebtTransaction(
      id: id ?? this.id,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amount': amount,
        'currencyCode': currencyCode,
        'isSettled': isSettled,
      };

  factory DebtTransaction.fromJson(Map<String, dynamic> json) => DebtTransaction(
        id: json['id'] as String,
        fromMemberId: json['fromMemberId'] as String,
        toMemberId: json['toMemberId'] as String,
        amount: (json['amount'] as num).toDouble(),
        currencyCode: json['currencyCode'] as String,
        isSettled: json['isSettled'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtTransaction &&
          runtimeType == other.runtimeType &&
          fromMemberId == other.fromMemberId &&
          toMemberId == other.toMemberId &&
          (amount - other.amount).abs() < 0.005;

  @override
  int get hashCode => Object.hash(fromMemberId, toMemberId, amount.toStringAsFixed(2));
}

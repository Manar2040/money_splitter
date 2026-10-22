class ExpenseSplit {
  final String memberId;
  final double amount;
  final double percentage; // optional, used in percentage split
  final double shares; // optional, used in shares split
  final bool isSettled;

  const ExpenseSplit({
    required this.memberId,
    required this.amount,
    this.percentage = 0.0,
    this.shares = 1.0,
    this.isSettled = false,
  });

  ExpenseSplit copyWith({
    String? memberId,
    double? amount,
    double? percentage,
    double? shares,
    bool? isSettled,
  }) {
    return ExpenseSplit(
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'amount': amount,
        'percentage': percentage,
        'shares': shares,
        'isSettled': isSettled,
      };

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
        memberId: json['memberId'] as String,
        amount: (json['amount'] as num).toDouble(),
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
        shares: (json['shares'] as num?)?.toDouble() ?? 1.0,
        isSettled: json['isSettled'] as bool? ?? false,
      );
}

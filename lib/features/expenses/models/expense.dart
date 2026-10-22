import 'expense_category.dart';
import 'expense_split.dart';
import 'split_type.dart';

class Expense {
  final String id;
  final String groupId;
  final String title;
  final double originalAmount;
  final String originalCurrency;
  final double baseAmount;
  final double exchangeRate;
  final ExpenseCategoryType category;
  final DateTime date;
  final Map<String, double> paidBy; // memberId -> amount paid in originalCurrency
  final List<ExpenseSplit> splits;
  final SplitType splitType;
  final String notes;
  final String? receiptPath;
  final bool isSettlement;
  final String? settlementPayerId;
  final String? settlementReceiverId;
  final String? linkedExpenseId; // Links a settlement to a specific expense if applicable
  final String? settlementCurrency; // Currency in which settlement was actually made
  final bool isFullSettlement; // Whether this settlement was intended to zero out the debt
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.originalAmount,
    required this.originalCurrency,
    required this.baseAmount,
    this.exchangeRate = 1.0,
    required this.category,
    required this.date,
    required this.paidBy,
    required this.splits,
    this.splitType = SplitType.equal,
    this.notes = '',
    this.receiptPath,
    this.isSettlement = false,
    this.settlementPayerId,
    this.settlementReceiverId,
    this.linkedExpenseId,
    this.settlementCurrency,
    this.isFullSettlement = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? id,
    String? groupId,
    String? title,
    double? originalAmount,
    String? originalCurrency,
    double? baseAmount,
    double? exchangeRate,
    ExpenseCategoryType? category,
    DateTime? date,
    Map<String, double>? paidBy,
    List<ExpenseSplit>? splits,
    SplitType? splitType,
    String? notes,
    String? receiptPath,
    bool? isSettlement,
    String? settlementPayerId,
    String? settlementReceiverId,
    String? linkedExpenseId,
    String? settlementCurrency,
    bool? isFullSettlement,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      baseAmount: baseAmount ?? this.baseAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      category: category ?? this.category,
      date: date ?? this.date,
      paidBy: paidBy ?? this.paidBy,
      splits: splits ?? this.splits,
      splitType: splitType ?? this.splitType,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
      isSettlement: isSettlement ?? this.isSettlement,
      settlementPayerId: settlementPayerId ?? this.settlementPayerId,
      settlementReceiverId: settlementReceiverId ?? this.settlementReceiverId,
      linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
      settlementCurrency: settlementCurrency ?? this.settlementCurrency,
      isFullSettlement: isFullSettlement ?? this.isFullSettlement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'title': title,
        'originalAmount': originalAmount,
        'originalCurrency': originalCurrency,
        'baseAmount': baseAmount,
        'exchangeRate': exchangeRate,
        'category': category.name,
        'date': date.toIso8601String(),
        'paidBy': paidBy,
        'splits': splits.map((s) => s.toJson()).toList(),
        'splitType': splitType.name,
        'notes': notes,
        'receiptPath': receiptPath,
        'isSettlement': isSettlement,
        'settlementPayerId': settlementPayerId,
        'settlementReceiverId': settlementReceiverId,
        'linkedExpenseId': linkedExpenseId,
        'settlementCurrency': settlementCurrency,
        'isFullSettlement': isFullSettlement,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        title: json['title'] as String,
        originalAmount: (json['originalAmount'] as num).toDouble(),
        originalCurrency: json['originalCurrency'] as String? ?? 'USD',
        baseAmount: (json['baseAmount'] as num).toDouble(),
        exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1.0,
        category: ExpenseCategoryType.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ExpenseCategoryType.general,
        ),
        date: DateTime.parse(json['date'] as String),
        paidBy: (json['paidBy'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        splits: (json['splits'] as List<dynamic>)
            .map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
            .toList(),
        splitType: SplitType.values.firstWhere(
          (s) => s.name == json['splitType'],
          orElse: () => SplitType.equal,
        ),
        notes: json['notes'] as String? ?? '',
        receiptPath: json['receiptPath'] as String?,
        isSettlement: json['isSettlement'] as bool? ?? false,
        settlementPayerId: json['settlementPayerId'] as String?,
        settlementReceiverId: json['settlementReceiverId'] as String?,
        linkedExpenseId: json['linkedExpenseId'] as String?,
        settlementCurrency: json['settlementCurrency'] as String?,
        isFullSettlement: json['isFullSettlement'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

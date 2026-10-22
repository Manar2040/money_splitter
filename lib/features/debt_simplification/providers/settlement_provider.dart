import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../groups/models/trip_group.dart';
import '../algorithms/debt_simplifier.dart';
import '../algorithms/debt_transaction.dart';

class SettlementProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  bool _isSimplifiedView = true;

  bool get isSimplifiedView => _isSimplifiedView;

  void toggleSimplification() {
    _isSimplifiedView = !_isSimplifiedView;
    notifyListeners();
  }

  /// Calculates net balances for all members in the group
  Map<String, double> getNetBalancesForGroup({
    required TripGroup group,
    required List<Expense> expenses,
    bool autoCleanDust = true,
  }) {
    return DebtSimplifier.calculateNetBalances(
      members: group.members,
      expenses: expenses,
      autoCleanDust: autoCleanDust,
    );
  }

  /// Returns debt transactions according to current toggle (Simplified vs Direct)
  /// Uses Connected Components to avoid "Stranger Debts" across isolated subgroups!
  List<DebtTransaction> getDebtTransactions({
    required TripGroup group,
    required List<Expense> expenses,
  }) {
    if (_isSimplifiedView) {
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: group.members,
        expenses: expenses,
        autoCleanDust: true,
      );
      return DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: group.baseCurrency,
        expenses: expenses,
        members: group.members,
      );
    } else {
      return DebtSimplifier.calculateDirectDebts(
        expenses: expenses,
        currencyCode: group.baseCurrency,
      );
    }
  }

  /// Computes overall user balance across all groups in base currency (e.g. USD)
  Map<String, double> calculateOverallUserBalance({
    required String currentUserId,
    required List<TripGroup> groups,
    required ExpenseProvider expenseProvider,
  }) {
    double youAreOwed = 0.0;
    double youOwe = 0.0;

    for (final group in groups) {
      final expenses = expenseProvider.getExpensesForGroup(group.id);
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: group.members,
        expenses: expenses,
        autoCleanDust: true,
      );

      final userBalanceInGroup = netBalances[currentUserId] ?? 0.0;
      if (userBalanceInGroup > 0.005) {
        youAreOwed += userBalanceInGroup;
      } else if (userBalanceInGroup < -0.005) {
        youOwe += (-userBalanceInGroup);
      }
    }

    return {
      'youAreOwed': youAreOwed,
      'youOwe': youOwe,
      'net': youAreOwed - youOwe,
    };
  }

  /// Performs a settlement payment between two members.
  /// Supports:
  /// 1. Multi-currency settlements (e.g. paying cash in EGP for a USD trip)
  /// 2. Zero-drift full settlements (eliminates phantom cent micro-debts)
  /// 3. Linking settlements to specific expenses (prevents ghost debt inversion upon deletion)
  Future<void> settleDebt({
    required TripGroup group,
    required String payerId,
    required String receiverId,
    required double amount,
    required ExpenseProvider expenseProvider,
    String? settlementCurrency,
    double? customExchangeRate,
    bool isFullSettlement = false,
    String? linkedExpenseId,
    String? note,
  }) async {
    final payerMember = group.members.firstWhere(
      (m) => m.id == payerId,
      orElse: () => throw StateError('Payer not in group'),
    );
    final receiverMember = group.members.firstWhere(
      (m) => m.id == receiverId,
      orElse: () => throw StateError('Receiver not in group'),
    );

    final currency = settlementCurrency ?? group.baseCurrency;
    double baseEquivalent = amount;

    if (currency != group.baseCurrency) {
      baseEquivalent = CurrencyFormatter.convert(
        amount: amount,
        fromCurrency: currency,
        toCurrency: group.baseCurrency,
        customExchangeRate: customExchangeRate,
      );
    }

    // Zero-drift closure: if marked as full settlement, adjust baseEquivalent to match exact balance owed
    if (isFullSettlement) {
      final currentExpenses = expenseProvider.getExpensesForGroup(group.id);
      final balances = DebtSimplifier.calculateNetBalances(
        members: group.members,
        expenses: currentExpenses,
      );
      final currentDebt = -(balances[payerId] ?? 0.0);
      if (currentDebt > 0) {
        baseEquivalent = currentDebt; // Exact closure eliminating any 2-cent rounding dust!
      }
    }

    final currencyLabel = currency != group.baseCurrency ? ' ($currency ${amount.toStringAsFixed(2)})' : '';

    final settlementExpense = Expense(
      id: _uuid.v4(),
      groupId: group.id,
      title: 'Settlement: ${payerMember.name} paid ${receiverMember.name}$currencyLabel',
      originalAmount: amount,
      originalCurrency: currency,
      baseAmount: baseEquivalent,
      exchangeRate: customExchangeRate ?? (amount > 0 ? baseEquivalent / amount : 1.0),
      category: ExpenseCategoryType.settlement,
      date: DateTime.now(),
      paidBy: {payerId: amount},
      splits: [],
      notes: note ?? (isFullSettlement ? 'Full settlement recorded' : 'Recorded settlement'),
      isSettlement: true,
      settlementPayerId: payerId,
      settlementReceiverId: receiverId,
      linkedExpenseId: linkedExpenseId,
      settlementCurrency: currency,
      isFullSettlement: isFullSettlement,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await expenseProvider.addExpense(settlementExpense);
    notifyListeners();
  }
}

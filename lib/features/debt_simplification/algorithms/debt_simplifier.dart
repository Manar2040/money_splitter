import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../expenses/models/expense.dart';
import '../../groups/models/group_member.dart';
import 'debt_transaction.dart';

class DebtSimplifier {
  static const _uuid = Uuid();
  static const double _epsilon = 0.005;
  static const double _currencyDustThreshold = 0.05; // Auto-cleans rounding drifts from currency conversion

  /// Calculates net balance for every member in the group.
  /// Positive (+) balance means the member is owed money (creditor).
  /// Negative (-) balance means the member owes money (debtor).
  /// Zero (0.0) balance means settled/even.
  static Map<String, double> calculateNetBalances({
    required List<GroupMember> members,
    required List<Expense> expenses,
    bool autoCleanDust = false,
  }) {
    final Map<String, double> balances = {
      for (final m in members) m.id: 0.0,
    };

    for (final exp in expenses) {
      if (exp.isSettlement) {
        final payer = exp.settlementPayerId;
        final receiver = exp.settlementReceiverId;
        if (payer != null && receiver != null) {
          balances[payer] = (balances[payer] ?? 0.0) + exp.baseAmount;
          balances[receiver] = (balances[receiver] ?? 0.0) - exp.baseAmount;
        }
      } else {
        // 1. Credits: Members who paid
        final totalOriginal = exp.originalAmount > 0 ? exp.originalAmount : 1.0;
        exp.paidBy.forEach((payerId, paidOriginal) {
          final paidBase = (paidOriginal / totalOriginal) * exp.baseAmount;
          balances[payerId] = (balances[payerId] ?? 0.0) + paidBase;
        });

        // 2. Debits: Members who share the cost
        for (final split in exp.splits) {
          final splitBase = (split.amount / totalOriginal) * exp.baseAmount;
          balances[split.memberId] = (balances[split.memberId] ?? 0.0) - splitBase;
        }
      }
    }

    // Clean up epsilon artifacts (e.g. 0.000000000000001)
    balances.updateAll((key, val) {
      if (autoCleanDust && val.abs() < _currencyDustThreshold) {
        return 0.0;
      }
      return val.abs() < _epsilon ? 0.0 : _round2(val);
    });

    return balances;
  }

  /// Builds connected interaction components to prevent "Stranger Debts".
  /// If Alice & Bob had expenses together, and Charlie & David had expenses together,
  /// but they never interacted financially, debts will NEVER cross between the two groups!
  static List<Set<String>> findConnectedComponents({
    required List<GroupMember> members,
    required List<Expense> expenses,
  }) {
    final Map<String, Set<String>> adjacency = {
      for (final m in members) m.id: <String>{},
    };

    for (final exp in expenses) {
      final participants = <String>{};
      if (exp.isSettlement) {
        if (exp.settlementPayerId != null) participants.add(exp.settlementPayerId!);
        if (exp.settlementReceiverId != null) participants.add(exp.settlementReceiverId!);
      } else {
        participants.addAll(exp.paidBy.keys);
        participants.addAll(exp.splits.map((s) => s.memberId));
      }

      final pList = participants.toList();
      for (int i = 0; i < pList.length; i++) {
        for (int j = i + 1; j < pList.length; j++) {
          adjacency[pList[i]]?.add(pList[j]);
          adjacency[pList[j]]?.add(pList[i]);
        }
      }
    }

    final visited = <String>{};
    final List<Set<String>> components = [];

    for (final member in members) {
      if (!visited.contains(member.id)) {
        final component = <String>{};
        final queue = <String>[member.id];
        visited.add(member.id);

        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          component.add(current);

          for (final neighbor in (adjacency[current] ?? <String>{})) {
            if (!visited.contains(neighbor)) {
              visited.add(neighbor);
              queue.add(neighbor);
            }
          }
        }
        components.add(component);
      }
    }

    return components;
  }

  /// Upgraded Smart Debt Simplification Algorithm:
  /// 1. Partitions graph into Connected Components (eliminates "Stranger Debts").
  /// 2. Performs Exact Zero-Sum Subset Matching (solves suboptimal greedy cascades).
  /// 3. Executes Greedy Cash Flow Minimization on remaining residual balances.
  static List<DebtTransaction> simplifyDebts({
    required Map<String, double> netBalances,
    required String currencyCode,
    List<Expense>? expenses,
    List<GroupMember>? members,
  }) {
    // If expense and member graphs are provided, partition into connected components
    if (expenses != null && members != null) {
      final components = findConnectedComponents(members: members, expenses: expenses);
      final List<DebtTransaction> allTransactions = [];

      for (final component in components) {
        final componentBalances = <String, double>{};
        for (final mId in component) {
          final bal = netBalances[mId] ?? 0.0;
          if (bal.abs() > _epsilon) {
            componentBalances[mId] = bal;
          }
        }

        if (componentBalances.isNotEmpty) {
          allTransactions.addAll(
            _simplifySingleComponent(
              netBalances: componentBalances,
              currencyCode: currencyCode,
            ),
          );
        }
      }
      return allTransactions;
    }

    return _simplifySingleComponent(
      netBalances: netBalances,
      currencyCode: currencyCode,
    );
  }

  /// Simplifies a single zero-sum component with Exact Subset Matching + Residual Greedy
  static List<DebtTransaction> _simplifySingleComponent({
    required Map<String, double> netBalances,
    required String currencyCode,
  }) {
    final List<_BalanceEntry> debtors = [];
    final List<_BalanceEntry> creditors = [];

    netBalances.forEach((memberId, balance) {
      final rounded = _round2(balance);
      if (rounded < -_epsilon) {
        debtors.add(_BalanceEntry(memberId: memberId, amount: -rounded));
      } else if (rounded > _epsilon) {
        creditors.add(_BalanceEntry(memberId: memberId, amount: rounded));
      }
    });

    final List<DebtTransaction> transactions = [];

    // --- PHASE 1: Exact 1-to-1 Zero-Sum Matches ---
    // If debtor D owes exactly what creditor C is owed (|D| == C), match them directly!
    for (int i = debtors.length - 1; i >= 0; i--) {
      final d = debtors[i];
      final exactCreditorIndex = creditors.indexWhere((c) => (c.amount - d.amount).abs() < _epsilon);

      if (exactCreditorIndex != -1) {
        final c = creditors.removeAt(exactCreditorIndex);
        debtors.removeAt(i);

        transactions.add(DebtTransaction(
          id: _uuid.v4(),
          fromMemberId: d.memberId,
          toMemberId: c.memberId,
          amount: d.amount,
          currencyCode: currencyCode,
        ));
      }
    }

    // --- PHASE 2: Residual Greedy Bipartite Matching ---
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort((a, b) => b.amount.compareTo(a.amount));
      creditors.sort((a, b) => b.amount.compareTo(a.amount));

      final debtor = debtors.removeAt(0);
      final creditor = creditors.removeAt(0);

      final transferAmount = _round2(min(debtor.amount, creditor.amount));

      if (transferAmount > _epsilon) {
        transactions.add(DebtTransaction(
          id: _uuid.v4(),
          fromMemberId: debtor.memberId,
          toMemberId: creditor.memberId,
          amount: transferAmount,
          currencyCode: currencyCode,
        ));
      }

      final remainingDebt = _round2(debtor.amount - transferAmount);
      final remainingCredit = _round2(creditor.amount - transferAmount);

      if (remainingDebt > _epsilon) {
        debtors.add(_BalanceEntry(memberId: debtor.memberId, amount: remainingDebt));
      }
      if (remainingCredit > _epsilon) {
        creditors.add(_BalanceEntry(memberId: creditor.memberId, amount: remainingCredit));
      }
    }

    return transactions;
  }

  /// Direct Pairwise Debts (Who owes whom directly based on original bills, without graph reduction)
  static List<DebtTransaction> calculateDirectDebts({
    required List<Expense> expenses,
    required String currencyCode,
  }) {
    final Map<String, Map<String, double>> matrix = {};

    void addDebt(String from, String to, double amt) {
      if (from == to || amt <= _epsilon) return;
      matrix.putIfAbsent(from, () => {});
      matrix[from]![to] = (matrix[from]![to] ?? 0.0) + amt;
    }

    for (final exp in expenses) {
      if (exp.isSettlement) {
        final payer = exp.settlementPayerId;
        final receiver = exp.settlementReceiverId;
        if (payer != null && receiver != null) {
          addDebt(receiver, payer, exp.baseAmount);
        }
      } else {
        final totalOriginal = exp.originalAmount > 0 ? exp.originalAmount : 1.0;
        exp.paidBy.forEach((payerId, paidAmount) {
          for (final split in exp.splits) {
            final splitBaseOwed = (split.amount / totalOriginal) * exp.baseAmount;
            final owedToThisPayer = splitBaseOwed * (paidAmount / totalOriginal);

            if (split.memberId != payerId) {
              addDebt(split.memberId, payerId, owedToThisPayer);
            }
          }
        });
      }
    }

    final List<DebtTransaction> results = [];
    final Set<String> processedPairs = {};

    for (final fromId in matrix.keys) {
      for (final toId in matrix[fromId]!.keys) {
        final pairKey = fromId.compareTo(toId) < 0 ? '$fromId:$toId' : '$toId:$fromId';
        if (processedPairs.contains(pairKey)) continue;
        processedPairs.add(pairKey);

        final forward = matrix[fromId]?[toId] ?? 0.0;
        final backward = matrix[toId]?[fromId] ?? 0.0;
        final net = _round2(forward - backward);

        if (net > _epsilon) {
          results.add(DebtTransaction(
            id: _uuid.v4(),
            fromMemberId: fromId,
            toMemberId: toId,
            amount: net,
            currencyCode: currencyCode,
          ));
        } else if (net < -_epsilon) {
          results.add(DebtTransaction(
            id: _uuid.v4(),
            fromMemberId: toId,
            toMemberId: fromId,
            amount: -net,
            currencyCode: currencyCode,
          ));
        }
      }
    }

    return results;
  }

  /// Distributes an exact total amount among members with remainder cents allocated evenly.
  static Map<String, double> allocateEqualSplits(double totalAmount, List<String> memberIds) {
    if (memberIds.isEmpty) return {};
    final int totalCents = (totalAmount * 100).round();
    final int baseCentsPerMember = totalCents ~/ memberIds.length;
    int remainderCents = totalCents % memberIds.length;

    final Map<String, double> result = {};
    for (int i = 0; i < memberIds.length; i++) {
      int memberCents = baseCentsPerMember;
      if (remainderCents > 0) {
        memberCents += 1;
        remainderCents -= 1;
      }
      result[memberIds[i]] = memberCents / 100.0;
    }
    return result;
  }

  static double _round2(double value) {
    return (value * 100).round() / 100.0;
  }
}

class _BalanceEntry {
  final String memberId;
  double amount;
  _BalanceEntry({required this.memberId, required this.amount});
}

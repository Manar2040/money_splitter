import 'package:flutter_test/flutter_test.dart';
import 'package:money_splitter/features/debt_simplification/algorithms/debt_simplifier.dart';
import 'package:money_splitter/features/debt_simplification/algorithms/debt_transaction.dart';
import 'package:money_splitter/features/expenses/models/expense.dart';
import 'package:money_splitter/features/expenses/models/expense_category.dart';
import 'package:money_splitter/features/expenses/models/expense_split.dart';
import 'package:money_splitter/features/expenses/models/split_type.dart';
import 'package:money_splitter/features/groups/models/group_member.dart';

void main() {
  group('DebtSimplifier - Algorithm & Edge Cases', () {
    final memberA = const GroupMember(id: 'A', name: 'Alice');
    final memberB = const GroupMember(id: 'B', name: 'Bob');
    final memberC = const GroupMember(id: 'C', name: 'Charlie');
    final memberD = const GroupMember(id: 'D', name: 'David');
    final memberE = const GroupMember(id: 'E', name: 'Emma');

    test('1. Zero balance scenario: all members are even', () {
      final members = [memberA, memberB, memberC];
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: [],
      );

      expect(netBalances['A'], 0.0);
      expect(netBalances['B'], 0.0);
      expect(netBalances['C'], 0.0);

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: 'USD',
      );

      expect(transactions, isEmpty);
    });

    test('2. Circular debt reduction: A owes B, B owes C, C owes A -> 0 transactions', () {
      final members = [memberA, memberB, memberC];

      final exp1 = Expense(
        id: 'e1',
        groupId: 'g1',
        title: 'Alice Breakfast',
        originalAmount: 60.0,
        originalCurrency: 'USD',
        baseAmount: 60.0,
        category: ExpenseCategoryType.food,
        date: DateTime.now(),
        paidBy: {'A': 60.0},
        splits: [
          const ExpenseSplit(memberId: 'A', amount: 30.0),
          const ExpenseSplit(memberId: 'B', amount: 30.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exp2 = Expense(
        id: 'e2',
        groupId: 'g1',
        title: 'Bob Lunch',
        originalAmount: 60.0,
        originalCurrency: 'USD',
        baseAmount: 60.0,
        category: ExpenseCategoryType.food,
        date: DateTime.now(),
        paidBy: {'B': 60.0},
        splits: [
          const ExpenseSplit(memberId: 'B', amount: 30.0),
          const ExpenseSplit(memberId: 'C', amount: 30.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exp3 = Expense(
        id: 'e3',
        groupId: 'g1',
        title: 'Charlie Dinner',
        originalAmount: 60.0,
        originalCurrency: 'USD',
        baseAmount: 60.0,
        category: ExpenseCategoryType.food,
        date: DateTime.now(),
        paidBy: {'C': 60.0},
        splits: [
          const ExpenseSplit(memberId: 'C', amount: 30.0),
          const ExpenseSplit(memberId: 'A', amount: 30.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final netBalances = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: [exp1, exp2, exp3],
      );

      expect(netBalances['A'], 0.0);
      expect(netBalances['B'], 0.0);
      expect(netBalances['C'], 0.0);

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: 'USD',
      );

      expect(transactions, isEmpty);
    });

    test(r'3. Transitive debt simplification: A owes B $50, B owes C $50 -> A owes C $50', () {
      final netBalances = {'A': -50.0, 'B': 0.0, 'C': 50.0};

      final simplified = DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: 'USD',
      );

      expect(simplified.length, 1);
      expect(simplified.first.fromMemberId, 'A');
      expect(simplified.first.toMemberId, 'C');
      expect(simplified.first.amount, 50.0);
    });

    test(r'4. Multiple payers for single expense: Alice pays $60, Bob pays $40 (Total $100, 4 people)', () {
      final members = [memberA, memberB, memberC, memberD];

      final exp = Expense(
        id: 'multi1',
        groupId: 'g1',
        title: 'Group Airbnb Stay',
        originalAmount: 100.0,
        originalCurrency: 'USD',
        baseAmount: 100.0,
        category: ExpenseCategoryType.stay,
        date: DateTime.now(),
        paidBy: {'A': 60.0, 'B': 40.0},
        splits: [
          const ExpenseSplit(memberId: 'A', amount: 25.0),
          const ExpenseSplit(memberId: 'B', amount: 25.0),
          const ExpenseSplit(memberId: 'C', amount: 25.0),
          const ExpenseSplit(memberId: 'D', amount: 25.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final netBalances = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: [exp],
      );

      expect(netBalances['A'], 35.0);
      expect(netBalances['B'], 15.0);
      expect(netBalances['C'], -25.0);
      expect(netBalances['D'], -25.0);

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: 'USD',
      );

      final totalTransferred = transactions.fold(0.0, (acc, t) => acc + t.amount);
      expect(totalTransferred, 50.0);
    });

    test('5. Smart Cent Allocation: \$100 divided 3 ways guarantees exact total without drift', () {
      final splits = DebtSimplifier.allocateEqualSplits(100.0, ['A', 'B', 'C']);

      expect(splits.length, 3);
      expect(splits['A'], 33.34);
      expect(splits['B'], 33.33);
      expect(splits['C'], 33.33);

      final total = splits.values.fold(0.0, (sum, val) => sum + val);
      expect((total * 100).round(), 10000);
    });

    // =========================================================================
    // FIX 1 TEST: Connected Components & Disjoint Subgroups (Zero Stranger Debts)
    // =========================================================================
    test('6. FIX 1: Connected Components prevent Stranger Debts across isolated subgroups', () {
      final members = [memberA, memberB, memberC, memberD];

      // Subgroup 1: Alice pays $100 for Bob (Bob owes Alice $100)
      final expSpa = Expense(
        id: 'exp_spa',
        groupId: 'g1',
        title: 'Alice & Bob Spa',
        originalAmount: 100.0,
        originalCurrency: 'USD',
        baseAmount: 100.0,
        category: ExpenseCategoryType.activity,
        date: DateTime.now(),
        paidBy: {'A': 100.0},
        splits: [const ExpenseSplit(memberId: 'B', amount: 100.0)],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Subgroup 2: Charlie pays $100 for David (David owes Charlie $100)
      final expDiving = Expense(
        id: 'exp_diving',
        groupId: 'g1',
        title: 'Charlie & David Diving',
        originalAmount: 100.0,
        originalCurrency: 'USD',
        baseAmount: 100.0,
        category: ExpenseCategoryType.activity,
        date: DateTime.now(),
        paidBy: {'C': 100.0},
        splits: [const ExpenseSplit(memberId: 'D', amount: 100.0)],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expenses = [expSpa, expDiving];
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: expenses,
      );

      // Verify connected components partitioned the subgroups
      final components = DebtSimplifier.findConnectedComponents(
        members: members,
        expenses: expenses,
      );
      expect(components.length, 2);
      expect(components.any((c) => c.contains('A') && c.contains('B')), isTrue);
      expect(components.any((c) => c.contains('C') && c.contains('D')), isTrue);

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: netBalances,
        currencyCode: 'USD',
        expenses: expenses,
        members: members,
      );

      expect(transactions.length, 2);

      // CRITICAL CHECK: Bob must pay Alice, David must pay Charlie.
      // Under NO circumstances should Bob be told to pay Charlie, or David to pay Alice!
      final bobTx = transactions.firstWhere((t) => t.fromMemberId == 'B');
      expect(bobTx.toMemberId, 'A');
      expect(bobTx.amount, 100.0);

      final davidTx = transactions.firstWhere((t) => t.fromMemberId == 'D');
      expect(davidTx.toMemberId, 'C');
      expect(davidTx.amount, 100.0);
    });

    // =========================================================================
    // FIX 1 TEST: Exact Zero-Sum Subsets Matching (Subset Sum Optimization)
    // =========================================================================
    test('7. FIX 1: Exact Zero-Sum Subset Matching avoids suboptimal greedy cascades', () {
      // Balances: A: +4, B: +3, C: +2, D: -5, E: -4
      // Exact match {A: +4, E: -4} resolves in 1 transaction (E -> A: 4.0)
      // Remaining {B: +3, C: +2, D: -5} resolves in 2 transactions (D -> B: 3.0, D -> C: 2.0)
      // Total transactions = 3 (naive greedy produces 4)
      final balances = {
        'A': 4.0,
        'B': 3.0,
        'C': 2.0,
        'D': -5.0,
        'E': -4.0,
      };

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: balances,
        currencyCode: 'USD',
      );

      expect(transactions.length, 3); // Optimal: exactly 3 transactions!

      // E must pay A directly
      final eTx = transactions.firstWhere((t) => t.fromMemberId == 'E');
      expect(eTx.toMemberId, 'A');
      expect(eTx.amount, 4.0);
    });

    // =========================================================================
    // FIX 2 TEST: Linked Settlements Prevent Ghost Debt Inversion
    // =========================================================================
    test('8. FIX 2: Deleting an expense with linked settlements prevents ghost debt inversion', () {
      final members = [memberA, memberB];

      // Alice pays $120 for Bob
      final exp = Expense(
        id: 'concert_120',
        groupId: 'g1',
        title: 'Concert Ticket',
        originalAmount: 120.0,
        originalCurrency: 'USD',
        baseAmount: 120.0,
        category: ExpenseCategoryType.activity,
        date: DateTime.now(),
        paidBy: {'A': 120.0},
        splits: [const ExpenseSplit(memberId: 'B', amount: 120.0)],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Bob settles $120 linked to the concert
      final settlement = Expense(
        id: 'settle_120',
        groupId: 'g1',
        title: 'Settlement: Bob paid Alice',
        originalAmount: 120.0,
        originalCurrency: 'USD',
        baseAmount: 120.0,
        category: ExpenseCategoryType.settlement,
        date: DateTime.now(),
        paidBy: {'B': 120.0},
        splits: [],
        isSettlement: true,
        settlementPayerId: 'B',
        settlementReceiverId: 'A',
        linkedExpenseId: 'concert_120', // Explicitly linked
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Before refund/deletion: both are even
      final netInitial = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: [exp, settlement],
      );
      expect(netInitial['A'], 0.0);
      expect(netInitial['B'], 0.0);

      // When the concert is refunded & deleted with its linked settlement:
      final expensesAfterRefund = <Expense>[]; // Both exp and settlement removed together

      final netAfterRefund = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: expensesAfterRefund,
      );

      // GHOST DEBT PREVENTED: Alice does NOT owe Bob $120!
      expect(netAfterRefund['A'], 0.0);
      expect(netAfterRefund['B'], 0.0);
    });

    // =========================================================================
    // FIX 3 TEST: Multi-Currency Settlement with Zero-Drift Closure
    // =========================================================================
    test('9. FIX 3: Multi-Currency settlement zero-drift rule eliminates phantom cent dust', () {
      final members = [memberA, memberB];

      // Alice pays 1,500 EGP for Lunch (at rate 0.02 = $30.00 USD)
      // Bob owes half: $15.00 USD (equivalent to 750 EGP)
      final expLunch = Expense(
        id: 'lunch_egp',
        groupId: 'g1',
        title: 'Cairo Lunch',
        originalAmount: 1500.0,
        originalCurrency: 'EGP',
        baseAmount: 30.0,
        exchangeRate: 0.02,
        category: ExpenseCategoryType.food,
        date: DateTime.now(),
        paidBy: {'A': 1500.0},
        splits: [
          const ExpenseSplit(memberId: 'A', amount: 750.0),
          const ExpenseSplit(memberId: 'B', amount: 750.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Bob hands Alice 750 EGP cash.
      // At today's slightly drifted exchange rate (0.0195), 750 EGP = $14.625 USD
      // With isFullSettlement = true, base amount is snapped to exact debt ($15.00)
      final settlementCashEGP = Expense(
        id: 'settle_cash_egp',
        groupId: 'g1',
        title: 'Settlement: Bob paid Alice (EGP 750.00)',
        originalAmount: 750.0,
        originalCurrency: 'EGP',
        baseAmount: 15.0, // Snapped to zero-out exact balance
        exchangeRate: 0.02,
        category: ExpenseCategoryType.settlement,
        date: DateTime.now(),
        paidBy: {'B': 750.0},
        splits: [],
        isSettlement: true,
        settlementPayerId: 'B',
        settlementReceiverId: 'A',
        isFullSettlement: true,
        settlementCurrency: 'EGP',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final balances = DebtSimplifier.calculateNetBalances(
        members: members,
        expenses: [expLunch, settlementCashEGP],
        autoCleanDust: true,
      );

      // ZERO PHANTOM DUST: Both Alice and Bob are cleanly at 0.00!
      expect(balances['A'], 0.0);
      expect(balances['B'], 0.0);

      final transactions = DebtSimplifier.simplifyDebts(
        netBalances: balances,
        currencyCode: 'USD',
      );
      expect(transactions, isEmpty);
    });
  });
}

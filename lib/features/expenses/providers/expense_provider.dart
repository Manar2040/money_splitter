import 'package:flutter/material.dart';
import '../../../database/local_storage_service.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class ExpenseProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();

  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _expenses = _storage.getAllExpenses();
    // Sort descending by date
    _expenses.sort((a, b) => b.date.compareTo(a.date));

    _isLoading = false;
    notifyListeners();
  }

  List<Expense> getExpensesForGroup(String groupId) {
    return _expenses.where((e) => e.groupId == groupId).toList();
  }

  Expense? getExpenseById(String expenseId) {
    try {
      return _expenses.firstWhere((e) => e.id == expenseId);
    } catch (_) {
      return null;
    }
  }

  /// Returns any settlements specifically linked to this expense
  List<Expense> getLinkedSettlements(String expenseId) {
    return _expenses.where((e) => e.isSettlement && e.linkedExpenseId == expenseId).toList();
  }

  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    await _storage.saveExpense(expense);
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      await _storage.saveExpense(expense);
      notifyListeners();
    }
  }

  /// Deletes an expense and automatically cleans up linked settlements
  /// to prevent the "Ghost Debt Inversion" trap!
  Future<void> deleteExpense(String expenseId, {bool deleteLinkedSettlements = true}) async {
    if (deleteLinkedSettlements) {
      final linked = getLinkedSettlements(expenseId);
      for (final s in linked) {
        _expenses.removeWhere((e) => e.id == s.id);
        await _storage.deleteExpense(s.id);
      }
    }

    _expenses.removeWhere((e) => e.id == expenseId);
    await _storage.deleteExpense(expenseId);
    notifyListeners();
  }

  /// Calculates total spend of a group (excluding settlements)
  double getTotalSpendForGroup(String groupId) {
    return getExpensesForGroup(groupId)
        .where((e) => !e.isSettlement)
        .fold(0.0, (sum, e) => sum + e.baseAmount);
  }

  /// Returns spending breakdown categorized by expense category
  Map<ExpenseCategoryType, double> getCategoryBreakdown(String groupId) {
    final groupExpenses = getExpensesForGroup(groupId).where((e) => !e.isSettlement);
    final Map<ExpenseCategoryType, double> map = {};

    for (final exp in groupExpenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.baseAmount;
    }
    return map;
  }
}

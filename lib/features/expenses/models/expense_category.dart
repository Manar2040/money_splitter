import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum ExpenseCategoryType {
  food,
  transport,
  stay,
  activity,
  groceries,
  shopping,
  general,
  settlement,
}

class ExpenseCategory {
  final ExpenseCategoryType type;
  final String label;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> all = [
    ExpenseCategory(
      type: ExpenseCategoryType.food,
      label: 'Food & Dining',
      icon: Icons.restaurant,
      color: AppColors.catFood,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.transport,
      label: 'Transport',
      icon: Icons.directions_car,
      color: AppColors.catTransport,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.stay,
      label: 'Accommodation',
      icon: Icons.hotel,
      color: AppColors.catStay,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.activity,
      label: 'Activity & Fun',
      icon: Icons.confirmation_number_outlined,
      color: AppColors.catActivity,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.groceries,
      label: 'Groceries',
      icon: Icons.shopping_basket,
      color: AppColors.catGroceries,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.shopping,
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      color: AppColors.catShopping,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.general,
      label: 'General',
      icon: Icons.receipt_long,
      color: AppColors.catGeneral,
    ),
    ExpenseCategory(
      type: ExpenseCategoryType.settlement,
      label: 'Settlement',
      icon: Icons.check_circle_outline,
      color: AppColors.settled,
    ),
  ];

  static ExpenseCategory fromType(ExpenseCategoryType type) {
    return all.firstWhere((cat) => cat.type == type, orElse: () => all.last);
  }

  static ExpenseCategory fromString(String name) {
    return all.firstWhere(
      (cat) => cat.type.name.toLowerCase() == name.toLowerCase(),
      orElse: () => all.firstWhere((c) => c.type == ExpenseCategoryType.general),
    );
  }
}

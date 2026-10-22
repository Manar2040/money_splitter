import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_boxes.dart';
import '../features/auth_user/models/user_profile.dart';
import '../features/groups/models/trip_group.dart';
import '../features/expenses/models/expense.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Box? _groupsBox;
  Box? _expensesBox;
  Box? _userProfileBox;
  Box? _settingsBox;

  // In-memory fallbacks to guarantee fault-tolerance
  final Map<String, dynamic> _memoryGroups = {};
  final Map<String, dynamic> _memoryExpenses = {};
  final Map<String, dynamic> _memoryUserProfile = {};
  final Map<String, dynamic> _memorySettings = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _groupsBox = await Hive.openBox(HiveBoxes.groups);
      _expensesBox = await Hive.openBox(HiveBoxes.expenses);
      _userProfileBox = await Hive.openBox(HiveBoxes.userProfile);
      _settingsBox = await Hive.openBox(HiveBoxes.settings);
    } catch (e) {
      debugPrint('Hive init error (falling back to robust in-memory): $e');
    }

    _isInitialized = true;
  }

  // --- Groups ---

  Future<void> saveGroup(TripGroup group) async {
    final jsonMap = group.toJson();
    _memoryGroups[group.id] = jsonMap;
    if (_groupsBox != null && _groupsBox!.isOpen) {
      await _groupsBox!.put(group.id, jsonEncode(jsonMap));
    }
  }

  Future<void> deleteGroup(String groupId) async {
    _memoryGroups.remove(groupId);
    if (_groupsBox != null && _groupsBox!.isOpen) {
      await _groupsBox!.delete(groupId);
    }

    // Also cascade delete expenses for this group
    final expenses = getExpensesForGroup(groupId);
    for (final exp in expenses) {
      await deleteExpense(exp.id);
    }
  }

  List<TripGroup> getGroups() {
    if (_groupsBox != null && _groupsBox!.isOpen) {
      final List<TripGroup> list = [];
      for (final key in _groupsBox!.keys) {
        final raw = _groupsBox!.get(key);
        if (raw != null) {
          try {
            final Map<String, dynamic> map = raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw);
            list.add(TripGroup.fromJson(map));
          } catch (e) {
            debugPrint('Failed to parse group $key: $e');
          }
        }
      }
      return list;
    }

    return _memoryGroups.values
        .map((m) => TripGroup.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // --- Expenses ---

  Future<void> saveExpense(Expense expense) async {
    final jsonMap = expense.toJson();
    _memoryExpenses[expense.id] = jsonMap;
    if (_expensesBox != null && _expensesBox!.isOpen) {
      await _expensesBox!.put(expense.id, jsonEncode(jsonMap));
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    _memoryExpenses.remove(expenseId);
    if (_expensesBox != null && _expensesBox!.isOpen) {
      await _expensesBox!.delete(expenseId);
    }
  }

  List<Expense> getAllExpenses() {
    if (_expensesBox != null && _expensesBox!.isOpen) {
      final List<Expense> list = [];
      for (final key in _expensesBox!.keys) {
        final raw = _expensesBox!.get(key);
        if (raw != null) {
          try {
            final Map<String, dynamic> map = raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw);
            list.add(Expense.fromJson(map));
          } catch (e) {
            debugPrint('Failed to parse expense $key: $e');
          }
        }
      }
      return list;
    }

    return _memoryExpenses.values
        .map((m) => Expense.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<Expense> getExpensesForGroup(String groupId) {
    return getAllExpenses().where((e) => e.groupId == groupId).toList();
  }

  // --- User Profile ---

  Future<void> saveUserProfile(UserProfile user) async {
    final jsonMap = user.toJson();
    _memoryUserProfile['current_user'] = jsonMap;
    if (_userProfileBox != null && _userProfileBox!.isOpen) {
      await _userProfileBox!.put('current_user', jsonEncode(jsonMap));
    }
  }

  UserProfile? getUserProfile() {
    if (_userProfileBox != null && _userProfileBox!.isOpen) {
      final raw = _userProfileBox!.get('current_user');
      if (raw != null) {
        try {
          final Map<String, dynamic> map = raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw);
          return UserProfile.fromJson(map);
        } catch (e) {
          debugPrint('Failed to parse user profile: $e');
        }
      }
    }

    if (_memoryUserProfile.containsKey('current_user')) {
      return UserProfile.fromJson(Map<String, dynamic>.from(_memoryUserProfile['current_user']));
    }
    return null;
  }

  // --- Settings ---

  Future<void> setSetting(String key, dynamic value) async {
    _memorySettings[key] = value;
    if (_settingsBox != null && _settingsBox!.isOpen) {
      await _settingsBox!.put(key, value);
    }
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    if (_settingsBox != null && _settingsBox!.isOpen) {
      return (_settingsBox!.get(key, defaultValue: defaultValue) as T?) ?? defaultValue;
    }
    return (_memorySettings[key] as T?) ?? defaultValue;
  }

  Future<void> clearAllData() async {
    _memoryGroups.clear();
    _memoryExpenses.clear();
    _memoryUserProfile.clear();
    _memorySettings.clear();

    if (_groupsBox != null && _groupsBox!.isOpen) await _groupsBox!.clear();
    if (_expensesBox != null && _expensesBox!.isOpen) await _expensesBox!.clear();
    if (_userProfileBox != null && _userProfileBox!.isOpen) await _userProfileBox!.clear();
    if (_settingsBox != null && _settingsBox!.isOpen) await _settingsBox!.clear();
  }
}

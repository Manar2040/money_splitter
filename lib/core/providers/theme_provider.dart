import 'package:flutter/material.dart';
import '../../database/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    final isDark = _storage.getSetting<bool>('is_dark_mode', defaultValue: false);
    _themeMode = (isDark ?? false) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _storage.setSetting('is_dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }
}

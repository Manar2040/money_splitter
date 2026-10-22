import 'package:flutter/material.dart';
import '../../../database/local_storage_service.dart';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();

  UserProfile _currentUser = const UserProfile(
    id: 'user_me',
    name: 'Omar',
    email: 'omar@splitwise.smart',
    defaultCurrency: 'USD',
  );

  UserProfile get currentUser => _currentUser;

  Future<void> init() async {
    final saved = _storage.getUserProfile();
    if (saved != null) {
      _currentUser = saved.copyWith(
        name: saved.name.replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '').trim(),
      );
    } else {
      await _storage.saveUserProfile(_currentUser);
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
    String? defaultCurrency,
  }) async {
    final clean = name?.replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '').trim();
    _currentUser = _currentUser.copyWith(
      name: clean ?? _currentUser.name,
      email: email ?? _currentUser.email,
      avatarUrl: avatarUrl ?? _currentUser.avatarUrl,
      defaultCurrency: defaultCurrency ?? _currentUser.defaultCurrency,
    );
    await _storage.saveUserProfile(_currentUser);
    notifyListeners();
  }

  /// Perspective switcher: Switch who is considered "You" (useful for testing & multi-user simulation)
  Future<void> switchActiveMemberPerspective({
    required String memberId,
    required String memberName,
    String? email,
  }) async {
    final clean = memberName.replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '').trim();
    _currentUser = UserProfile(
      id: memberId,
      name: clean,
      email: email ?? '$clean@splitwise.smart',
      defaultCurrency: _currentUser.defaultCurrency,
    );
    await _storage.saveUserProfile(_currentUser);
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import '../../../database/local_storage_service.dart';
import '../models/group_member.dart';
import '../models/trip_group.dart';

class GroupProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();

  List<TripGroup> _groups = [];
  String? _activeGroupId;
  bool _isLoading = false;

  List<TripGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get activeGroupId => _activeGroupId;

  TripGroup? get activeGroup {
    if (_activeGroupId == null) return _groups.isNotEmpty ? _groups.first : null;
    return _groups.firstWhere(
      (g) => g.id == _activeGroupId,
      orElse: () => _groups.isNotEmpty ? _groups.first : throw StateError('No group found'),
    );
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _groups = _storage.getGroups();
    if (_groups.isNotEmpty && _activeGroupId == null) {
      _activeGroupId = _groups.first.id;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setActiveGroup(String groupId) {
    _activeGroupId = groupId;
    notifyListeners();
  }

  TripGroup? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  Future<void> createTrip(TripGroup group) async {
    _groups.insert(0, group);
    _activeGroupId = group.id;
    await _storage.saveGroup(group);
    notifyListeners();
  }

  Future<void> updateTrip(TripGroup group) async {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
      await _storage.saveGroup(group);
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String groupId) async {
    _groups.removeWhere((g) => g.id == groupId);
    if (_activeGroupId == groupId) {
      _activeGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    }
    await _storage.deleteGroup(groupId);
    notifyListeners();
  }

  Future<void> addMember(String groupId, GroupMember member) async {
    final group = getGroupById(groupId);
    if (group == null) return;

    if (group.members.any((m) => m.id == member.id)) return;

    final updatedMembers = List<GroupMember>.from(group.members)..add(member);
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    await updateTrip(updatedGroup);
  }

  Future<void> removeMember(String groupId, String memberId) async {
    final group = getGroupById(groupId);
    if (group == null) return;

    final updatedMembers = group.members.where((m) => m.id != memberId).toList();
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    await updateTrip(updatedGroup);
  }
}

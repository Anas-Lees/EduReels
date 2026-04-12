import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/reel.dart';
import '../services/api_service.dart';

class GroupProvider extends ChangeNotifier {
  List<Group> _groups = [];
  bool _loading = false;
  String? _error;

  List<Group> get groups => _groups;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadGroups() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await ApiService.getGroups();
    } catch (e) {
      _error = 'Failed to load groups';
    }
    _loading = false;
    notifyListeners();
  }

  Future<Group?> createGroup(String name, String description) async {
    try {
      final group = await ApiService.createGroup(name, description);
      _groups.insert(0, group);
      notifyListeners();
      return group;
    } catch (e) {
      _error = 'Failed to create group';
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await ApiService.deleteGroup(groupId);
      _groups.removeWhere((g) => g.id == groupId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete group';
      notifyListeners();
    }
  }

  Future<List<Reel>> getGroupReels(String groupId) async {
    return await ApiService.getGroupReels(groupId);
  }
}

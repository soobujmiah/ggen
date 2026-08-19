import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_profile.dart';

class WorkspaceProfileStore {
  WorkspaceProfileStore({this.maxProfiles = 8});
  static const _key = 'workspace.profiles.v1';
  final int maxProfiles;

  Future<List<WorkspaceProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw.take(maxProfiles).map(WorkspaceProfile.decode).toList(growable: false);
  }

  Future<void> save(List<WorkspaceProfile> profiles) async {
    final bounded = profiles.take(maxProfiles).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, bounded.map((profile) => profile.encode()).toList());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String encodeForTest(List<WorkspaceProfile> profiles) =>
      jsonEncode(profiles.take(8).map((profile) => profile.toJson()).toList());
}

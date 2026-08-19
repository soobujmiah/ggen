import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences {
  const WorkspacePreferences({this.inspectorVisible = true});
  final bool inspectorVisible;

  static const _inspectorKey = 'workspace.inspector_visible';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inspectorKey, inspectorVisible);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
  }
}

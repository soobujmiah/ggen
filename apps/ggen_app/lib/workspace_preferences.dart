import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences {
  const WorkspacePreferences({this.inspectorVisible = true, this.canvasFirst = true});
  final bool inspectorVisible;
  final bool canvasFirst;

  static const _inspectorKey = 'workspace.inspector_visible';
  static const _canvasFirstKey = 'workspace.canvas_first';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
      canvasFirst: prefs.getBool(_canvasFirstKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inspectorKey, inspectorVisible);
    await prefs.setBool(_canvasFirstKey, canvasFirst);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
  }
}

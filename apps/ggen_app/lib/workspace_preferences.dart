import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences {
  const WorkspacePreferences({this.inspectorVisible = true, this.canvasFirst = true, this.inspectorDock = 'right'});
  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  static const _inspectorKey = 'workspace.inspector_visible';
  static const _canvasFirstKey = 'workspace.canvas_first';
  static const _inspectorDockKey = 'workspace.inspector_dock';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
      canvasFirst: prefs.getBool(_canvasFirstKey) ?? true,
      inspectorDock: prefs.getString(_inspectorDockKey) ?? 'right',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inspectorKey, inspectorVisible);
    await prefs.setBool(_canvasFirstKey, canvasFirst);
    await prefs.setString(_inspectorDockKey, inspectorDock);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
    await prefs.remove(_inspectorDockKey);
  }
}

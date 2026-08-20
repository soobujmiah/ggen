import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferences {
  const WorkspacePreferences({
    this.inspectorVisible = true,
    this.canvasFirst = true,
    this.inspectorDock = 'right',
    this.lastProjectKey,
  });

  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  /// Stable storage key of the most recently saved project, used to restore
  /// the last workspace on startup. Null when nothing was saved yet.
  final String? lastProjectKey;

  static const _inspectorKey = 'workspace.inspector_visible';
  static const _canvasFirstKey = 'workspace.canvas_first';
  static const _inspectorDockKey = 'workspace.inspector_dock';
  static const _lastProjectKeyPref = 'workspace.last_project_key';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_lastProjectKeyPref) ?? '';
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
      canvasFirst: prefs.getBool(_canvasFirstKey) ?? true,
      inspectorDock: prefs.getString(_inspectorDockKey) ?? 'right',
      lastProjectKey: savedKey.isEmpty ? null : savedKey,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inspectorKey, inspectorVisible);
    await prefs.setBool(_canvasFirstKey, canvasFirst);
    await prefs.setString(_inspectorDockKey, inspectorDock);
    if (lastProjectKey != null) {
      await prefs.setString(_lastProjectKeyPref, lastProjectKey!);
    } else {
      await prefs.remove(_lastProjectKeyPref);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
    await prefs.remove(_inspectorDockKey);
    await prefs.remove(_lastProjectKeyPref);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted workspace preferences, including the top action-bar
/// customization (order + which actions are pinned outside the More menu)
/// and the secondary canvas-toolbar collapsed state.
class WorkspacePreferences {
  const WorkspacePreferences({
    this.inspectorVisible = true,
    this.canvasFirst = true,
    this.inspectorDock = 'right',
    this.lastProjectKey,
    this.secondaryToolbarCollapsed = false,
    this.topActionOrder = const <String>[],
    this.topActionPinned = const <String>[],
  });

  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  /// Stable storage key of the most recently saved project, used to restore
  /// the last workspace on startup. Null when nothing was saved yet.
  final String? lastProjectKey;

  /// Whether the secondary canvas toolbar (undo/redo/layers/zoom row above
  /// the navigation bar) starts collapsed on the next launch.
  final bool secondaryToolbarCollapsed;

  /// Canonical order of the top action-bar actions (the More menu order).
  /// Empty means the built-in default order.
  final List<String> topActionOrder;

  /// Actions pinned to the overlay top bar (outside the More menu), in the
  /// order they should appear; bounded and sanitized on load.
  final List<String> topActionPinned;

  static const _inspectorKey = 'workspace.inspector_visible';
  static const _canvasFirstKey = 'workspace.canvas_first';
  static const _inspectorDockKey = 'workspace.inspector_dock';
  static const _lastProjectKeyPref = 'workspace.last_project_key';
  static const _toolbarCollapsedKey = 'workspace.secondary_toolbar_collapsed';
  static const _topActionOrderKey = 'workspace.top_action_order';
  static const _topActionPinnedKey = 'workspace.top_action_pinned';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_lastProjectKeyPref) ?? '';
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
      canvasFirst: prefs.getBool(_canvasFirstKey) ?? true,
      inspectorDock: prefs.getString(_inspectorDockKey) ?? 'right',
      lastProjectKey: savedKey.isEmpty ? null : savedKey,
      secondaryToolbarCollapsed:
          prefs.getBool(_toolbarCollapsedKey) ?? false,
      topActionOrder: prefs.getStringList(_topActionOrderKey) ?? const <String>[],
      topActionPinned:
          prefs.getStringList(_topActionPinnedKey) ?? const <String>[],
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
    await prefs.setBool(_toolbarCollapsedKey, secondaryToolbarCollapsed);
    await prefs.setStringList(_topActionOrderKey, topActionOrder);
    await prefs.setStringList(_topActionPinnedKey, topActionPinned);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
    await prefs.remove(_inspectorDockKey);
    await prefs.remove(_lastProjectKeyPref);
    await prefs.remove(_toolbarCollapsedKey);
    await prefs.remove(_topActionOrderKey);
    await prefs.remove(_topActionPinnedKey);
  }
}

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
    this.secondaryToolbarMode = 'full',
    this.secondaryToolbarDock = 'bottom',
    this.topActionOrder = const <String>[],
    this.topActionPinned = const <String>[],
  });

  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  /// Stable storage key of the most recently saved project, used to restore
  /// the last workspace on startup. Null when nothing was saved yet.
  final String? lastProjectKey;

  /// Secondary canvas toolbar state. [secondaryToolbarMode] is one of
  /// 'full' (all buttons), 'mini' (compact essentials strip) or 'hidden'
  /// (no remnant at all); [secondaryToolbarDock] is 'bottom', 'left' or
  /// 'right'. Unknown values fail closed to 'full'/'bottom' on load.
  final String secondaryToolbarMode;
  final String secondaryToolbarDock;

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
  static const _toolbarModeKey = 'workspace.secondary_toolbar_mode';
  static const _toolbarDockKey = 'workspace.secondary_toolbar_dock';
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
      secondaryToolbarMode:
          prefs.getString(_toolbarModeKey) ?? 'full',
      secondaryToolbarDock:
          prefs.getString(_toolbarDockKey) ?? 'bottom',
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
    await prefs.setString(_toolbarModeKey, secondaryToolbarMode);
    await prefs.setString(_toolbarDockKey, secondaryToolbarDock);
    await prefs.setStringList(_topActionOrderKey, topActionOrder);
    await prefs.setStringList(_topActionPinnedKey, topActionPinned);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
    await prefs.remove(_inspectorDockKey);
    await prefs.remove(_lastProjectKeyPref);
    await prefs.remove(_toolbarModeKey);
    await prefs.remove(_toolbarDockKey);
    await prefs.remove(_topActionOrderKey);
    await prefs.remove(_topActionPinnedKey);
  }
}

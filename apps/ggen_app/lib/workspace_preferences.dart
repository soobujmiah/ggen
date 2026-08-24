import 'package:shared_preferences/shared_preferences.dart';

/// Persisted workspace preferences, including the top action-bar
/// customization (order + which actions are pinned outside the More menu).
///
/// The legacy secondary-toolbar mode/dock keys ('full'/'mini'/'hidden',
/// 'bottom'/'left'/'right') are retired with the canonical mobile
/// workspace shell: the compact layout now has ONE stable tool rail and
/// ONE contextual action bar, neither of which is dockable or
/// collapsible. Stored legacy values are ignored on load and removed on
/// the next save/clear so stale customization cannot resurrect the old
/// layout. Project data is untouched.
class WorkspacePreferences {
  const WorkspacePreferences({
    this.inspectorVisible = true,
    this.canvasFirst = true,
    this.inspectorDock = 'right',
    this.lastProjectKey,
    this.topActionOrder = const <String>[],
    this.topActionPinned = const <String>[],
  });

  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  /// Stable storage key of the most recently saved project, used to restore
  /// the last workspace on startup. Null when nothing was saved yet.
  final String? lastProjectKey;

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
  static const _topActionOrderKey = 'workspace.top_action_order';
  static const _topActionPinnedKey = 'workspace.top_action_pinned';

  /// Retired keys of the removed dockable secondary toolbar; cleaned up on
  /// save/clear so no stale layout state lingers on-device.
  static const _legacyToolbarModeKey = 'workspace.secondary_toolbar_mode';
  static const _legacyToolbarDockKey = 'workspace.secondary_toolbar_dock';

  static Future<WorkspacePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_lastProjectKeyPref) ?? '';
    return WorkspacePreferences(
      inspectorVisible: prefs.getBool(_inspectorKey) ?? true,
      canvasFirst: prefs.getBool(_canvasFirstKey) ?? true,
      inspectorDock: prefs.getString(_inspectorDockKey) ?? 'right',
      lastProjectKey: savedKey.isEmpty ? null : savedKey,
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
    await prefs.setStringList(_topActionOrderKey, topActionOrder);
    await prefs.setStringList(_topActionPinnedKey, topActionPinned);
    await prefs.remove(_legacyToolbarModeKey);
    await prefs.remove(_legacyToolbarDockKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inspectorKey);
    await prefs.remove(_canvasFirstKey);
    await prefs.remove(_inspectorDockKey);
    await prefs.remove(_lastProjectKeyPref);
    await prefs.remove(_topActionOrderKey);
    await prefs.remove(_topActionPinnedKey);
    await prefs.remove(_legacyToolbarModeKey);
    await prefs.remove(_legacyToolbarDockKey);
  }
}

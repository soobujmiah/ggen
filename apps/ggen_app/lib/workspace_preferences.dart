import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted workspace preferences, including the top action-bar
/// customization (order + which actions are pinned outside the More menu)
/// and the free-form fullscreen control layout.
///
/// The legacy secondary-toolbar mode/dock keys ('full'/'mini'/'hidden',
/// 'bottom'/'left'/'right') are retired with the canonical mobile
/// workspace shell: the compact layout now has ONE stable tool rail and
/// ONE contextual action bar, neither of which is dockable or
/// collapsible. Stored legacy values are ignored on load and removed on
/// the next save/clear so stale customization cannot resurrect the old
/// layout. Project data is untouched.
///
/// The region-based fullscreen layout key (`workspace.fullscreen_regions`)
/// is also retired: fullscreen controls are now free-form floating
/// clusters persisted under `workspace.fullscreen_clusters`. The legacy
/// key is still READ on load so existing placements migrate, and it is
/// removed on the next save/clear.
class WorkspacePreferences {
  const WorkspacePreferences({
    this.inspectorVisible = true,
    this.canvasFirst = true,
    this.inspectorDock = 'right',
    this.lastProjectKey,
    this.topActionOrder = const <String>[],
    this.topActionPinned = const <String>[],
    this.fullscreenClusters = const <String, dynamic>{},
    this.fullscreenRegions = const <String, List<String>>{},
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

  /// Free-form fullscreen control layout in the current format
  /// (`{"clusters": [{"id", "x", "y", "controls": [...]}]}`), as edited by
  /// dragging clusters in fullscreen and by the "Customize fullscreen
  /// controls" sheet. Empty means the built-in default layout. Stored as
  /// one JSON string; sanitized by `CanvasControlLayout.fromPrefs` on load
  /// so unknown ids fail closed.
  final Map<String, dynamic> fullscreenClusters;

  /// LEGACY region-based fullscreen placement (region name → control ids).
  /// Read on load only, so existing placements migrate to the cluster
  /// model; never written by `save()` (which removes the stored key).
  final Map<String, List<String>> fullscreenRegions;

  static const _inspectorKey = 'workspace.inspector_visible';
  static const _canvasFirstKey = 'workspace.canvas_first';
  static const _inspectorDockKey = 'workspace.inspector_dock';
  static const _lastProjectKeyPref = 'workspace.last_project_key';
  static const _topActionOrderKey = 'workspace.top_action_order';
  static const _topActionPinnedKey = 'workspace.top_action_pinned';
  static const _fullscreenClustersKey = 'workspace.fullscreen_clusters';

  /// Retired region-based fullscreen key: still read for migration, removed
  /// on save/clear.
  static const _fullscreenRegionsKey = 'workspace.fullscreen_regions';

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
      fullscreenClusters: _decodeClusters(prefs.getString(_fullscreenClustersKey)),
      fullscreenRegions: _decodeRegions(prefs.getString(_fullscreenRegionsKey)),
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
    if (fullscreenClusters.isEmpty) {
      await prefs.remove(_fullscreenClustersKey);
    } else {
      await prefs.setString(
        _fullscreenClustersKey,
        jsonEncode(fullscreenClusters),
      );
    }
    // Migrated: the legacy region format is never written again.
    await prefs.remove(_fullscreenRegionsKey);
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
    await prefs.remove(_fullscreenClustersKey);
    await prefs.remove(_fullscreenRegionsKey);
    await prefs.remove(_legacyToolbarModeKey);
    await prefs.remove(_legacyToolbarDockKey);
  }

  /// Decodes the stored fullscreen cluster JSON, failing closed to an empty
  /// map on any malformed input so a corrupt value cannot crash the shell.
  static Map<String, dynamic> _decodeClusters(String? raw) {
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <String, dynamic>{};
      return decoded;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  /// Decodes the stored legacy region JSON, failing closed to an empty
  /// map on any malformed input so a corrupt value cannot crash the shell.
  static Map<String, List<String>> _decodeRegions(String? raw) {
    if (raw == null || raw.isEmpty) return const <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String, List<String>>{};
      }
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is List) {
          result[entry.key] = value
              .whereType<String>()
              .toList(growable: false);
        }
      }
      return result;
    } catch (_) {
      return const <String, List<String>>{};
    }
  }
}

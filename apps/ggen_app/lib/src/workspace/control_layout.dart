import 'package:flutter/material.dart';

/// Every action that can be placed on the canvas as a persistent control,
/// in normal or fullscreen (immersive) mode.
///
/// Single source of truth for control identity, order, labels and icons so
/// pinning, region placement and iconography cannot drift between surfaces.
enum CanvasControl {
  undo('Undo', Icons.undo),
  redo('Redo', Icons.redo),
  zoomIn('Zoom in', Icons.add),
  zoomOut('Zoom out', Icons.remove),
  zoomFit('Fit to screen', Icons.fit_screen_outlined),
  grid('Grid', Icons.grid_4x4),
  layers('Layers', Icons.layers_outlined),
  multiSelect('Multi-select', Icons.done_all_outlined),
  columns('Columns', Icons.view_column_outlined),
  newProject('New project', Icons.note_add_outlined),
  save('Save project', Icons.save_outlined),
  diagnostics('Diagnostics export', Icons.bug_report_outlined),
  settings('Settings', Icons.tune),
  immersive('Immersive canvas', Icons.fullscreen),
  dockInspector('Dock inspector', Icons.vertical_split_outlined);

  const CanvasControl(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Named screen regions where fullscreen controls can be placed.
///
/// Order here is the canonical render order (top-left → bottom-right) and
/// the dedupe order: when a control appears in more than one region, the
/// region that appears first in this enum keeps it.
enum ControlRegion {
  topLeft('Top-left'),
  topCenter('Top-center'),
  topRight('Top-right'),
  bottomLeft('Bottom-left'),
  bottomCenter('Bottom-center'),
  bottomRight('Bottom-right');

  const ControlRegion(this.label);

  final String label;
}

/// Device/workstation class used to select the workspace layout.
///
/// Replaces the old single `width < 700` breakpoint so landscape phones are
/// no longer misclassified as "wide desktop":
///
/// - [wide]: width >= 700 AND height >= 600 — tablets, large portrait
///   phones, desktop. Left tool rail + dockable inspector + status bar.
/// - [compactLandscape]: not wide and width > height — landscape phones.
///   One compact landscape bar, maximum usable canvas.
/// - [compactPortrait]: otherwise — portrait phones. Canonical mobile shell
///   (left rail + contextual action bar).
enum WorkspaceClass { compactPortrait, compactLandscape, wide }

/// Deterministic device-class selection (pure, unit tested).
WorkspaceClass classifyWorkspace(double width, double height) {
  if (width >= 700 && height >= 600) return WorkspaceClass.wide;
  if (width > height) return WorkspaceClass.compactLandscape;
  return WorkspaceClass.compactPortrait;
}

/// User-defined fullscreen control placement.
///
/// Immutable value type over a `Map<ControlRegion, List<CanvasControl>>`,
/// normalized by [resolve] so every surface renders the same deterministic
/// layout: unknown entries dropped, duplicates collapsed (first region in
/// [ControlRegion.values] order wins), per-region capacity enforced, and the
/// [CanvasControl.immersive] exit control always guaranteed present.
class CanvasControlLayout {
  CanvasControlLayout(Map<ControlRegion, List<CanvasControl>> regions)
      : _regions = Map<ControlRegion, List<CanvasControl>>.unmodifiable({
          for (final entry in regions.entries)
            entry.key: List<CanvasControl>.unmodifiable(entry.value),
        });

  final Map<ControlRegion, List<CanvasControl>> _regions;

  /// Hard deterministic per-region capacity. Beyond this the customization
  /// sheet rejects placements, so clusters stay small and cannot collide.
  static const int maxControlsPerRegion = 6;

  Map<ControlRegion, List<CanvasControl>> get regions => _regions;

  /// Sensible first-run layout: document actions top-right, history + the
  /// movable floating zoom cluster bottom-right, context tools bottom-left.
  factory CanvasControlLayout.defaults() => CanvasControlLayout({
    ControlRegion.topRight: const [
      CanvasControl.save,
      CanvasControl.newProject,
      CanvasControl.settings,
    ],
    ControlRegion.bottomRight: const [
      CanvasControl.undo,
      CanvasControl.redo,
      CanvasControl.zoomOut,
      CanvasControl.zoomFit,
      CanvasControl.zoomIn,
      CanvasControl.grid,
    ],
    ControlRegion.bottomLeft: const [
      CanvasControl.layers,
      CanvasControl.multiSelect,
      CanvasControl.columns,
    ],
  });

  /// Loads a stored layout (region name → control ids), failing closed on
  /// unknown regions/controls and normalizing through [resolve].
  factory CanvasControlLayout.fromPrefs(Map<String, List<String>> raw) {
    final byName = <String, CanvasControl>{
      for (final control in CanvasControl.values) control.name: control,
    };
    final regions = <ControlRegion, List<CanvasControl>>{};
    for (final entry in raw.entries) {
      ControlRegion? region;
      for (final candidate in ControlRegion.values) {
        if (candidate.name == entry.key) {
          region = candidate;
          break;
        }
      }
      if (region == null) continue;
      regions[region] = [
        for (final id in entry.value)
          if (byName[id] != null) byName[id]!,
      ];
    }
    return CanvasControlLayout(regions).resolve();
  }

  /// Stable persistence encoding (region name → control ids).
  Map<String, List<String>> toPrefs() => <String, List<String>>{
    for (final entry in _regions.entries)
      entry.key.name: [for (final control in entry.value) control.name],
  };

  /// Deterministic normalization:
  /// 1. iterate regions in [ControlRegion.values] order;
  /// 2. a control keeps only its first region (later duplicates dropped);
  /// 3. each region is capped at [maxControlsPerRegion];
  /// 4. [CanvasControl.immersive] is guaranteed present (first slot of
  ///    topRight, dropping the last user control only when the region is
  ///    full) so the user can never be locked inside fullscreen.
  CanvasControlLayout resolve() {
    final result = <ControlRegion, List<CanvasControl>>{};
    final placed = <CanvasControl>{};
    for (final region in ControlRegion.values) {
      final list = <CanvasControl>[];
      for (final control in _regions[region] ?? const <CanvasControl>[]) {
        if (!placed.add(control)) continue;
        list.add(control);
      }
      if (list.length > maxControlsPerRegion) {
        list.removeRange(maxControlsPerRegion, list.length);
      }
      if (list.isNotEmpty) result[region] = list;
    }
    if (!placed.contains(CanvasControl.immersive)) {
      final topRight = result[ControlRegion.topRight] ?? <CanvasControl>[];
      result[ControlRegion.topRight] = <CanvasControl>[
        CanvasControl.immersive,
        ...topRight,
      ].take(maxControlsPerRegion).toList(growable: false);
    }
    return CanvasControlLayout(result);
  }

  /// Deterministic snap: which region a drop point belongs to, using a
  /// 3-column × 2-row grid over the viewport (horizontal thirds, vertical
  /// halves). Pure math, unit tested; used by the cluster drag handler.
  static ControlRegion nearestRegion(Offset drop, Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return ControlRegion.bottomRight;
    }
    final tx = drop.dx / viewport.width;
    final ty = drop.dy / viewport.height;
    final column = tx < 1 / 3
        ? 0
        : tx > 2 / 3
        ? 2
        : 1;
    final row = ty < 0.5 ? 0 : 1;
    if (column == 1 && row == 0) return ControlRegion.topCenter;
    if (column == 1 && row == 1) return ControlRegion.bottomCenter;
    if (column == 0 && row == 0) return ControlRegion.topLeft;
    if (column == 2 && row == 0) return ControlRegion.topRight;
    if (column == 0 && row == 1) return ControlRegion.bottomLeft;
    return ControlRegion.bottomRight;
  }
}
